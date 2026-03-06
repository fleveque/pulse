defmodule PulseWeb.PortfolioLive do
  use PulseWeb, :live_view

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Pulse.PubSub, "portfolio:#{slug}")
    end

    portfolio = fetch_portfolio(slug)

    holding_count =
      if portfolio, do: length(portfolio.holdings), else: 0

    description = "#{slug}'s dividend portfolio on Pulse — #{holding_count} holdings"

    {:ok,
     assign(socket,
       page_title: "#{slug}'s Portfolio",
       meta_description: description,
       meta_url: url(~p"/p/#{slug}"),
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
        <.icon name="hero-briefcase" class="size-16 mx-auto text-base-content/20 mb-4" />
        <h1 class="text-2xl font-bold text-base-content/40 mb-2">Portfolio not found</h1>
        <p class="text-base-content/50">
          The portfolio "{@slug}" doesn't exist or hasn't been shared yet.
        </p>
        <.link navigate="/" class="btn btn-primary btn-sm mt-4">
          Back to dashboard
        </.link>
      </div>

      <div :if={!@not_found && @portfolio}>
        <%!-- Header --%>
        <div class="flex items-center justify-between mb-8">
          <div>
            <div class="flex items-center gap-3">
              <span class="flex items-center justify-center size-12 rounded-full bg-primary/15 text-primary text-xl font-bold">
                {@slug |> String.first() |> String.upcase()}
              </span>
              <div>
                <h1 class="text-2xl font-bold">{@slug}</h1>
                <p class="text-base-content/50 text-sm">
                  {length(@portfolio.holdings)} holdings
                </p>
              </div>
            </div>
          </div>
          <div class="flex items-center gap-2">
            <button
              id="share-btn"
              phx-hook="ShareButton"
              data-url={url(~p"/p/#{@slug}")}
              data-title={"#{@slug}'s Portfolio · Pulse"}
              data-text={"Check out #{@slug}'s dividend portfolio on Pulse"}
              class="btn btn-ghost btn-sm"
            >
              <.icon name="hero-share-micro" class="size-4" />
              <span id="share-label">Share</span>
            </button>
            <.link navigate="/" class="btn btn-ghost btn-sm">
              <.icon name="hero-arrow-left-micro" class="size-4" /> Dashboard
            </.link>
          </div>
        </div>

        <%!-- Allocation Bar --%>
        <div
          :if={length(@portfolio.metrics[:allocations] || []) > 0}
          class="mb-8"
        >
          <div class="flex rounded-full overflow-hidden h-4 bg-base-300">
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
        </div>

        <%!-- Stock Grid --%>
        <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-3">
          <div
            :for={
              {alloc, idx} <-
                Enum.with_index(sorted_allocations(@portfolio.metrics[:allocations]))
            }
            class="card bg-base-200 border border-base-300 hover:border-primary/30 transition-colors"
          >
            <div class="card-body p-4 items-center text-center">
              <div class="mb-2">
                <.stock_logo symbol={alloc.symbol} />
              </div>
              <p class="font-bold text-sm">{alloc.symbol}</p>
              <div class="flex items-center gap-1.5">
                <div class={"w-2.5 h-2.5 rounded-full flex-shrink-0 " <> allocation_color(idx)}></div>
                <span class="text-lg font-bold tabular-nums">{alloc.percentage}%</span>
              </div>
            </div>
          </div>
        </div>

        <%!-- Empty state --%>
        <div :if={@portfolio.holdings == []} class="text-center py-12">
          <.icon name="hero-chart-pie" class="size-12 mx-auto text-base-content/20 mb-3" />
          <p class="text-base-content/50">This portfolio has no holdings yet.</p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp sorted_allocations(nil), do: []

  defp sorted_allocations(allocations) do
    Enum.sort_by(allocations, fn a -> -a.percentage end)
  end

  @allocation_colors ~w(
    bg-emerald-500 bg-blue-500 bg-purple-500 bg-orange-500 bg-pink-500
    bg-cyan-500 bg-indigo-500 bg-teal-500 bg-rose-500 bg-amber-500
    bg-lime-500 bg-sky-500 bg-fuchsia-500
  )

  defp allocation_color(index) do
    Enum.at(@allocation_colors, rem(index, length(@allocation_colors)))
  end
end
