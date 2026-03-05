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
        <%!-- Header --%>
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

        <%!-- Summary Cards --%>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-6">
          <div class="card bg-base-200 border border-base-300">
            <div class="card-body p-5">
              <p class="text-sm text-base-content/50 uppercase tracking-wide font-medium">
                Total Value
              </p>
              <p class="text-2xl font-bold text-base-content">
                {format_currency(@portfolio.metrics[:total_value])}
              </p>
            </div>
          </div>
          <div class="card bg-base-200 border border-base-300">
            <div class="card-body p-5">
              <p class="text-sm text-base-content/50 uppercase tracking-wide font-medium">
                Holdings
              </p>
              <p class="text-2xl font-bold text-base-content">
                {@portfolio.metrics[:holding_count] || 0}
              </p>
            </div>
          </div>
          <div class="card bg-base-200 border border-base-300">
            <div class="card-body p-5">
              <p class="text-sm text-base-content/50 uppercase tracking-wide font-medium">
                Avg Position
              </p>
              <p class="text-2xl font-bold text-base-content">
                {format_currency(avg_position(@portfolio.metrics))}
              </p>
            </div>
          </div>
        </div>

        <%!-- Holdings Table --%>
        <div class="card bg-base-200 border border-base-300 overflow-hidden mb-6">
          <div class="card-body p-0">
            <table class="table">
              <thead>
                <tr>
                  <th>Symbol</th>
                  <th class="text-right">Quantity</th>
                  <th class="text-right">Avg Price</th>
                  <th class="text-right">Value</th>
                  <th class="text-right">Allocation</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={alloc <- sorted_allocations(@portfolio.metrics[:allocations])}
                  class="hover"
                >
                  <td class="font-semibold">{alloc.symbol}</td>
                  <td class="text-right">
                    {format_number(find_field(@portfolio.holdings, alloc.symbol, "quantity"))}
                  </td>
                  <td class="text-right">
                    {format_currency(find_field(@portfolio.holdings, alloc.symbol, "avg_price"))}
                  </td>
                  <td class="text-right font-medium">{format_currency(alloc.value)}</td>
                  <td class="text-right">
                    <div class="flex items-center justify-end gap-2">
                      <div class="w-16 bg-base-300 rounded-full h-2 hidden sm:block">
                        <div
                          class="bg-primary rounded-full h-2"
                          style={"width: #{min(alloc.percentage, 100)}%"}
                        >
                        </div>
                      </div>
                      <span class="text-sm tabular-nums">{alloc.percentage}%</span>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <%!-- Allocation Chart (visual bars) --%>
        <div
          :if={length(@portfolio.metrics[:allocations] || []) > 0}
          class="card bg-base-200 border border-base-300"
        >
          <div class="card-body p-5">
            <h2 class="text-lg font-bold mb-3">Allocation</h2>
            <div class="flex rounded-full overflow-hidden h-6 bg-base-300">
              <div
                :for={
                  {alloc, idx} <-
                    Enum.with_index(sorted_allocations(@portfolio.metrics[:allocations]))
                }
                class={"h-full " <> allocation_color(idx)}
                style={"width: #{alloc.percentage}%"}
                title={"#{alloc.symbol}: #{alloc.percentage}%"}
              >
              </div>
            </div>
            <div class="flex flex-wrap gap-3 mt-3">
              <div
                :for={
                  {alloc, idx} <-
                    Enum.with_index(sorted_allocations(@portfolio.metrics[:allocations]))
                }
                class="flex items-center gap-1.5 text-sm"
              >
                <div class={"w-3 h-3 rounded-full " <> allocation_color(idx)}></div>
                <span class="font-medium">{alloc.symbol}</span>
                <span class="text-base-content/50">{alloc.percentage}%</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp sorted_allocations(nil), do: []

  defp sorted_allocations(allocations) do
    Enum.sort_by(allocations, fn a -> -a.percentage end)
  end

  defp find_field(holdings, symbol, field) do
    case Enum.find(holdings, fn h -> h["symbol"] == symbol end) do
      nil -> 0
      h -> h[field] || 0
    end
  end

  defp avg_position(%{total_value: total, holding_count: count}) when count > 0 do
    total / count
  end

  defp avg_position(_), do: 0

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

  @allocation_colors ~w(
    bg-primary bg-secondary bg-accent bg-info bg-success bg-warning bg-error
    bg-primary/70 bg-secondary/70 bg-accent/70 bg-info/70 bg-success/70
  )

  defp allocation_color(index) do
    Enum.at(@allocation_colors, rem(index, length(@allocation_colors)))
  end
end
