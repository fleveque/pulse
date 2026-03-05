defmodule Pulse.PortfolioWorker do
  @moduledoc """
  GenServer that maintains live portfolio state for an opted-in user.

  Each worker holds the current holdings, computed metrics (allocation percentages,
  sector distribution, dividend info), and pushes updates to connected LiveView
  clients via Phoenix PubSub.
  """
  use GenServer

  require Logger

  defstruct [:slug, holdings: [], metrics: %{}]

  # Client API

  def start_link(slug) do
    GenServer.start_link(__MODULE__, slug, name: via(slug))
  end

  def get_portfolio(slug) do
    GenServer.call(via(slug), :get_portfolio)
  end

  def update_holdings(slug, holdings) do
    GenServer.cast(via(slug), {:update_holdings, holdings})
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
  def handle_cast({:update_holdings, holdings}, state) do
    new_state = %{state | holdings: holdings, metrics: compute_metrics(holdings)}

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
      |> Enum.map(fn h -> (h["quantity"] || 0) * (h["avg_price"] || 0) end)
      |> Enum.sum()

    allocations =
      holdings
      |> Enum.map(fn h ->
        value = (h["quantity"] || 0) * (h["avg_price"] || 0)
        pct = if total_value > 0, do: Float.round(value / total_value * 100, 2), else: 0.0

        %{
          symbol: h["symbol"],
          value: value,
          percentage: pct
        }
      end)

    %{
      total_value: total_value,
      holding_count: length(holdings),
      allocations: allocations
    }
  end
end
