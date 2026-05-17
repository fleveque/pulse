defmodule Pulse.PortfolioWorker do
  @moduledoc """
  GenServer that maintains live portfolio state for an opted-in user.

  Each worker holds the current holdings, computed metrics (allocation percentages,
  sector distribution, dividend info), and pushes updates to connected LiveView
  clients via Phoenix PubSub.

  ## NATS payload versions

  - v1 (legacy): `{holdings: [{symbol, quantity, avg_price, price}, ...]}`. Values
    are summed as plain numbers — assumed to be in a single (USD) currency.
  - v2: `{version: 2, base_currency, holdings: [{..., currency, value_in_base,
    value_in_usd}, ...]}`. The worker sums `value_in_base` for the user-facing
    `total_value` and `value_in_usd` for `total_value_in_usd`, which the
    community dashboard uses for cross-portfolio aggregation.

  `update_holdings/2` accepts either a bare list (v1, kept for older tests
  and callers) or the full payload map (v2-aware).
  """
  use GenServer

  require Logger

  defstruct [:slug, holdings: [], metrics: %{}, base_currency: "USD", stats: nil]

  # Client API

  def start_link(slug) do
    GenServer.start_link(__MODULE__, slug, name: via(slug))
  end

  def get_portfolio(slug) do
    GenServer.call(via(slug), :get_portfolio)
  end

  def update_holdings(slug, holdings) when is_list(holdings) do
    update_holdings(slug, %{"holdings" => holdings})
  end

  def update_holdings(slug, payload) when is_map(payload) do
    GenServer.cast(via(slug), {:update_holdings, payload})
  end

  # Server callbacks

  @impl true
  def init(slug) do
    Logger.info("Starting portfolio worker for #{slug}")
    {:ok, %__MODULE__{slug: slug}}
  end

  @impl true
  def handle_call(:get_portfolio, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:update_holdings, payload}, state) do
    holdings = payload["holdings"] || []
    base_currency = payload["base_currency"] || "USD"
    # Rails ships pre-aggregated YoC / current yield / sectors as of payload v2.
    # Older payloads (v1, or v2 from a pre-stats deploy) leave this nil — the
    # LiveView templates already guard for it.
    stats = payload["stats"]

    new_state = %{
      state
      | holdings: holdings,
        base_currency: base_currency,
        metrics: compute_metrics(holdings),
        stats: stats
    }

    Pulse.Store.put(state.slug, new_state)

    Phoenix.PubSub.broadcast(
      Pulse.PubSub,
      "portfolio:#{state.slug}",
      {:portfolio_updated, new_state}
    )

    # Notify dashboard aggregator
    Phoenix.PubSub.broadcast(
      Pulse.PubSub,
      "portfolios",
      {:portfolio_changed, state.slug}
    )

    {:noreply, new_state}
  end

  defp via(slug) do
    {:via, Registry, {Pulse.PortfolioRegistry, slug}}
  end

  defp compute_metrics(holdings) do
    total_value =
      holdings
      |> Enum.map(&holding_value/1)
      |> Enum.sum()

    total_value_in_usd =
      holdings
      |> Enum.map(&holding_value_in_usd/1)
      |> Enum.sum()

    allocations =
      holdings
      |> Enum.map(fn h ->
        value = holding_value(h)
        pct = if total_value > 0, do: Float.round(value / total_value * 100, 2), else: 0.0

        %{
          symbol: h["symbol"],
          value: value,
          percentage: pct
        }
      end)

    %{
      total_value: total_value,
      total_value_in_usd: total_value_in_usd,
      holding_count: length(holdings),
      allocations: allocations
    }
  end

  # v2 payloads pre-compute value_in_base in the user's preferred currency;
  # v1 payloads fall through to the legacy quantity × price.
  defp holding_value(%{"value_in_base" => value}) when is_number(value), do: value

  defp holding_value(h) do
    (h["quantity"] || 0) * (h["price"] || h["avg_price"] || 0)
  end

  # value_in_usd is the cross-portfolio normalization key used by the community
  # dashboard. When absent (v1 or USD-only v2 payload) fall back to the same
  # plain math.
  defp holding_value_in_usd(%{"value_in_usd" => value}) when is_number(value), do: value
  defp holding_value_in_usd(h), do: holding_value(h)
end
