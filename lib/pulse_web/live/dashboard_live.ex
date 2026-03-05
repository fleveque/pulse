defmodule PulseWeb.DashboardLive do
  use PulseWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Pulse.PubSub, "dashboard")
    end

    {:ok,
     assign(socket,
       page_title: "Community Dashboard",
       portfolio_count: 0,
       popular_stocks: [],
       recent_activity: []
     )}
  end

  @impl true
  def handle_info({:dashboard_updated, stats}, socket) do
    {:noreply, assign(socket, stats)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mb-8">
        <h1 class="text-3xl font-bold">Pulse</h1>
        <p class="text-base-content/60 mt-1">Community dividend portfolio dashboard</p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div class="card bg-base-200 border border-base-300">
          <div class="card-body">
            <p class="text-sm text-base-content/50 uppercase tracking-wide font-medium">
              Shared Portfolios
            </p>
            <p class="text-3xl font-bold text-base-content">{@portfolio_count}</p>
          </div>
        </div>
        <div class="card bg-base-200 border border-base-300">
          <div class="card-body">
            <p class="text-sm text-base-content/50 uppercase tracking-wide font-medium">
              Popular Stocks
            </p>
            <p class="text-3xl font-bold text-base-content">{length(@popular_stocks)}</p>
          </div>
        </div>
        <div class="card bg-base-200 border border-base-300">
          <div class="card-body">
            <p class="text-sm text-base-content/50 uppercase tracking-wide font-medium">
              Recent Activity
            </p>
            <p class="text-3xl font-bold text-base-content">{length(@recent_activity)}</p>
          </div>
        </div>
      </div>

      <div class="card bg-base-200 border border-base-300">
        <div class="card-body">
          <h2 class="card-title">Getting Started</h2>
          <p class="text-base-content/70">
            Pulse shows real-time community dividend portfolio data.
            Share your portfolio from
            <a href="https://quantic.es" class="link link-primary">quantic.es</a>
            to appear here.
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
