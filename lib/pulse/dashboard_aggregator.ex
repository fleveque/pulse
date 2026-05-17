defmodule Pulse.DashboardAggregator do
  @moduledoc """
  GenServer that aggregates stats across all active portfolio workers
  and broadcasts dashboard updates via PubSub.

  Listens for portfolio changes and recomputes community-wide stats:
  total portfolios, total holdings, most popular stocks, total value.
  """
  use GenServer

  require Logger

  @recompute_debounce 500

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  def refresh do
    GenServer.call(__MODULE__, :refresh)
  end

  @impl true
  def init(_opts) do
    Phoenix.PubSub.subscribe(Pulse.PubSub, "portfolios")
    {:ok, %{stats: compute_stats(), debounce_ref: nil}}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  def handle_call(:refresh, _from, state) do
    stats = compute_stats()
    {:reply, stats, %{state | stats: stats}}
  end

  @impl true
  def handle_info(:recompute, state) do
    stats = compute_stats()

    Phoenix.PubSub.broadcast(Pulse.PubSub, "dashboard", {:dashboard_updated, stats})

    {:noreply, %{state | stats: stats, debounce_ref: nil}}
  end

  def handle_info({:portfolio_changed, _slug}, state) do
    # Debounce recomputation — multiple rapid updates only trigger one recompute
    if state.debounce_ref, do: Process.cancel_timer(state.debounce_ref)
    ref = Process.send_after(self(), :recompute, @recompute_debounce)
    {:noreply, %{state | debounce_ref: ref}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp compute_stats do
    children = DynamicSupervisor.which_children(Pulse.PortfolioSupervisor)

    portfolios =
      children
      |> Enum.filter(fn {_, pid, _, _} -> is_pid(pid) end)
      |> Enum.map(fn {_, pid, _, _} ->
        try do
          GenServer.call(pid, :get_portfolio, 2_000)
        catch
          :exit, _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    all_holdings =
      portfolios
      |> Enum.flat_map(& &1.holdings)

    # Community dashboard sums in USD so per-user base currencies don't double-count.
    # v2 workers populate total_value_in_usd; older workers (or USD-only v2) fall back
    # to total_value, which is the same number in that case.
    total_value =
      portfolios
      |> Enum.map(fn p -> p.metrics[:total_value_in_usd] || p.metrics[:total_value] || 0 end)
      |> Enum.sum()

    stock_counts =
      all_holdings
      |> Enum.group_by(fn h -> h["symbol"] end)
      |> Enum.map(fn {symbol, holdings} ->
        %{
          symbol: symbol,
          holders: length(holdings),
          total_quantity: holdings |> Enum.map(fn h -> h["quantity"] || 0 end) |> Enum.sum()
        }
      end)
      |> Enum.sort_by(fn s -> -s.holders end)

    %{
      portfolio_count: length(portfolios),
      total_holdings: length(all_holdings),
      total_value: Float.round(total_value * 1.0, 2),
      popular_stocks: Enum.take(stock_counts, 10),
      portfolio_slugs: Enum.map(portfolios, & &1.slug),
      community_sectors: community_sectors(portfolios),
      community_yoc: community_average(portfolios, "yoc"),
      community_current_yield: community_average(portfolios, "currentYield")
    }
  end

  # Simple mean across portfolios that ship a stats block — answers "what's the
  # typical Quantic user's yield?" rather than a value-weighted aggregate. Nil
  # if no worker has stats yet (newer Rails ships them, older deploys don't).
  defp community_average(portfolios, key) do
    values =
      portfolios
      |> Enum.filter(fn p -> is_map(p.stats) end)
      |> Enum.map(fn p -> p.stats[key] end)
      |> Enum.filter(&is_number/1)

    case values do
      [] -> nil
      vs -> Float.round(Enum.sum(vs) / length(vs), 2)
    end
  end

  # Community-wide sector breakdown. Each worker ships its own pre-aggregated
  # `sectors` list (in the user's display currency) in `state.stats`. We can't
  # safely add those across different display currencies, so we weight by each
  # portfolio's `total_value_in_usd` to normalise. Returns an empty list when
  # no worker has stats yet.
  defp community_sectors(portfolios) do
    with_stats =
      portfolios
      |> Enum.filter(fn p -> is_map(p.stats) && is_list(p.stats["sectors"]) end)

    if with_stats == [] do
      []
    else
      totals =
        with_stats
        |> Enum.flat_map(fn p ->
          portfolio_usd = (p.metrics[:total_value_in_usd] || p.metrics[:total_value] || 0) * 1.0

          Enum.map(p.stats["sectors"], fn s ->
            {s["sector"] || "Unknown", (s["percent"] || 0) / 100.0 * portfolio_usd}
          end)
        end)
        |> Enum.reduce(%{}, fn {sector, value}, acc ->
          Map.update(acc, sector, value, &(&1 + value))
        end)

      grand_total = totals |> Map.values() |> Enum.sum()

      if grand_total <= 0 do
        []
      else
        totals
        |> Enum.map(fn {sector, value} ->
          %{
            sector: sector,
            value: Float.round(value, 2),
            percent: Float.round(value / grand_total * 100, 1)
          }
        end)
        |> Enum.sort_by(& &1.value, :desc)
      end
    end
  end
end
