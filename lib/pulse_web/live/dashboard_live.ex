defmodule PulseWeb.DashboardLive do
  use PulseWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Pulse.PubSub, "dashboard")
    end

    stats = Pulse.DashboardAggregator.get_stats()

    {:ok,
     assign(socket,
       page_title: "Community Dashboard",
       portfolio_count: stats.portfolio_count,
       total_holdings: stats.total_holdings,
       total_value: stats.total_value,
       popular_stocks: stats.popular_stocks,
       portfolio_slugs: stats.portfolio_slugs
     )}
  end

  @impl true
  def handle_info({:dashboard_updated, stats}, socket) do
    {:noreply,
     assign(socket,
       portfolio_count: stats.portfolio_count,
       total_holdings: stats.total_holdings,
       total_value: stats.total_value,
       popular_stocks: stats.popular_stocks,
       portfolio_slugs: stats.portfolio_slugs
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mb-8">
        <h1 class="text-3xl font-bold">Pulse</h1>
        <p class="text-base-content/60 mt-1">Community dividend portfolio dashboard</p>
      </div>

      <%!-- Stats --%>
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
        <div class="card bg-base-200 border border-base-300">
          <div class="card-body p-5">
            <p class="text-sm text-base-content/50 uppercase tracking-wide font-medium">
              Shared Portfolios
            </p>
            <p class="text-3xl font-bold text-base-content">{@portfolio_count}</p>
          </div>
        </div>
        <div class="card bg-base-200 border border-base-300">
          <div class="card-body p-5">
            <p class="text-sm text-base-content/50 uppercase tracking-wide font-medium">
              Total Holdings
            </p>
            <p class="text-3xl font-bold text-base-content">{@total_holdings}</p>
          </div>
        </div>
        <div class="card bg-base-200 border border-base-300">
          <div class="card-body p-5">
            <p class="text-sm text-base-content/50 uppercase tracking-wide font-medium">
              Community Value
            </p>
            <p class="text-3xl font-bold text-base-content">{format_currency(@total_value)}</p>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <%!-- Popular Stocks --%>
        <div class="card bg-base-200 border border-base-300">
          <div class="card-body p-5">
            <h2 class="text-lg font-bold mb-3">Popular Stocks</h2>
            <div :if={@popular_stocks == []} class="text-base-content/50 text-sm py-4 text-center">
              No stocks yet. Share your portfolio from
              <a href="https://quantic.es" class="link link-primary">quantic.es</a>
              to appear here.
            </div>
            <table :if={@popular_stocks != []} class="table table-sm">
              <thead>
                <tr>
                  <th>Symbol</th>
                  <th class="text-right">Holders</th>
                  <th class="text-right">Total Qty</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={stock <- @popular_stocks}>
                  <td class="font-semibold">{stock.symbol}</td>
                  <td class="text-right">{stock.holders}</td>
                  <td class="text-right">{format_number(stock.total_quantity)}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <%!-- Shared Portfolios --%>
        <div class="card bg-base-200 border border-base-300">
          <div class="card-body p-5">
            <h2 class="text-lg font-bold mb-3">Shared Portfolios</h2>
            <div
              :if={@portfolio_slugs == []}
              class="text-base-content/50 text-sm py-4 text-center"
            >
              No portfolios shared yet.
            </div>
            <div :if={@portfolio_slugs != []} class="flex flex-wrap gap-2">
              <.link
                :for={slug <- @portfolio_slugs}
                navigate={~p"/p/#{slug}"}
                class="btn btn-sm btn-outline"
              >
                {slug}
              </.link>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp format_currency(value) when is_number(value) do
    "$#{:erlang.float_to_binary(value * 1.0, decimals: 2)}"
  end

  defp format_currency(_), do: "$0.00"

  defp format_number(value) when is_float(value) do
    if value == Float.floor(value) do
      "#{trunc(value)}"
    else
      :erlang.float_to_binary(value, decimals: 2)
    end
  end

  defp format_number(value) when is_integer(value), do: "#{value}"
  defp format_number(_), do: "0"
end
