defmodule PulseWeb.PortfolioLive do
  use PulseWeb, :live_view

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Pulse.PubSub, "portfolio:#{slug}")
    end

    portfolio = fetch_portfolio(slug)

    {:ok,
     assign(socket,
       page_title: "#{slug}'s Portfolio",
       slug: slug,
       portfolio: portfolio,
       not_found: is_nil(portfolio)
     )}
  end

  @impl true
  def handle_info({:portfolio_updated, portfolio}, socket) do
    {:noreply, assign(socket, portfolio: portfolio, not_found: false)}
  end

  defp fetch_portfolio(slug) do
    case Registry.lookup(Pulse.PortfolioRegistry, slug) do
      [{_pid, _}] -> Pulse.PortfolioWorker.get_portfolio(slug)
      [] -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div :if={@not_found} class="text-center py-16">
        <h1 class="text-2xl font-bold text-base-content/40 mb-2">Portfolio not found</h1>
        <p class="text-base-content/50">
          The portfolio "{@slug}" doesn't exist or hasn't been shared yet.
        </p>
        <.link navigate="/" class="link link-primary mt-4 inline-block">
          Back to dashboard
        </.link>
      </div>

      <div :if={!@not_found && @portfolio}>
        <div class="flex items-center justify-between mb-6">
          <div>
            <h1 class="text-3xl font-bold">{@slug}'s Portfolio</h1>
            <p class="text-base-content/50 mt-1">
              {length(@portfolio.holdings)} holdings
            </p>
          </div>
          <.link navigate="/" class="btn btn-ghost btn-sm">
            Dashboard
          </.link>
        </div>

        <div :if={@portfolio.metrics[:total_value]} class="card bg-base-200 border border-base-300 mb-6">
          <div class="card-body">
            <p class="text-sm text-base-content/50 uppercase tracking-wide font-medium">
              Total Value
            </p>
            <p class="text-3xl font-bold text-base-content">
              ${Float.round(@portfolio.metrics.total_value, 2)}
            </p>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300 overflow-hidden">
          <table class="table">
            <thead>
              <tr>
                <th>Symbol</th>
                <th class="text-right">Quantity</th>
                <th class="text-right">Avg Price</th>
                <th class="text-right">Allocation</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={alloc <- @portfolio.metrics[:allocations] || []}>
                <td class="font-medium">{alloc.symbol}</td>
                <td class="text-right">
                  {find_holding(@portfolio.holdings, alloc.symbol)["quantity"]}
                </td>
                <td class="text-right">
                  ${find_holding(@portfolio.holdings, alloc.symbol)["avg_price"]}
                </td>
                <td class="text-right">{alloc.percentage}%</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp find_holding(holdings, symbol) do
    Enum.find(holdings, %{}, fn h -> h["symbol"] == symbol end)
  end
end
