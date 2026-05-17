defmodule PulseWeb.DashboardLive do
  use PulseWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Pulse.PubSub, "dashboard")
    end

    stats = Pulse.DashboardAggregator.get_stats()

    description =
      "Real-time community dividend portfolio dashboard. " <>
        "#{stats.portfolio_count} portfolios tracking #{stats.total_holdings} holdings."

    top_visited = Pulse.Analytics.top_visited(5)

    {:ok,
     assign(socket,
       page_title: gettext("Community Dashboard"),
       meta_description: description,
       meta_url: url(~p"/"),
       portfolio_count: stats.portfolio_count,
       total_holdings: stats.total_holdings,
       total_value: stats.total_value,
       show_value: stats.portfolio_count > 5 and stats.total_value > 100_000,
       popular_stocks: stats.popular_stocks,
       portfolio_slugs: stats.portfolio_slugs,
       community_sectors: Map.get(stats, :community_sectors, []),
       community_yoc: Map.get(stats, :community_yoc),
       community_current_yield: Map.get(stats, :community_current_yield),
       top_visited: top_visited
     )}
  end

  @impl true
  def handle_info({:dashboard_updated, stats}, socket) do
    {:noreply,
     assign(socket,
       portfolio_count: stats.portfolio_count,
       total_holdings: stats.total_holdings,
       total_value: stats.total_value,
       show_value: stats.portfolio_count > 5 and stats.total_value > 100_000,
       popular_stocks: stats.popular_stocks,
       portfolio_slugs: stats.portfolio_slugs,
       community_sectors: Map.get(stats, :community_sectors, []),
       community_yoc: Map.get(stats, :community_yoc),
       community_current_yield: Map.get(stats, :community_current_yield)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <%!-- Hero Section --%>
      <div class="text-center mb-10">
        <div class="flex justify-center mb-4">
          <div class="relative">
            <Layouts.pulse_logo size={72} />
            <span class="absolute -top-1 -right-1 flex size-4">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-violet-500 opacity-75">
              </span>
              <span class="relative inline-flex rounded-full size-4 bg-violet-500"></span>
            </span>
          </div>
        </div>
        <h1 class="text-4xl font-extrabold tracking-tight">
          Pulse
        </h1>
        <p class="text-base-content/50 mt-2 text-lg">
          {gettext("Real-time community dividend portfolio dashboard")}
        </p>
      </div>

      <%!-- Stats Cards --%>
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-10">
        <div class="card bg-gradient-to-br from-emerald-500/10 to-emerald-600/5 border border-emerald-500/20">
          <div class="card-body p-5">
            <div class="flex items-center gap-3">
              <div class="rounded-xl bg-emerald-500/15 p-2.5">
                <.icon name="hero-user-group" class="size-5 text-emerald-600 dark:text-emerald-400" />
              </div>
              <div>
                <p class="text-xs text-base-content/50 uppercase tracking-wider font-semibold">
                  {gettext("Portfolios")}
                </p>
                <p class="text-2xl font-bold">{@portfolio_count}</p>
              </div>
            </div>
          </div>
        </div>

        <div class="card bg-gradient-to-br from-blue-500/10 to-blue-600/5 border border-blue-500/20">
          <div class="card-body p-5">
            <div class="flex items-center gap-3">
              <div class="rounded-xl bg-blue-500/15 p-2.5">
                <.icon name="hero-chart-bar" class="size-5 text-blue-600 dark:text-blue-400" />
              </div>
              <div>
                <p class="text-xs text-base-content/50 uppercase tracking-wider font-semibold">
                  {gettext("Holdings")}
                </p>
                <p class="text-2xl font-bold">{@total_holdings}</p>
              </div>
            </div>
          </div>
        </div>

        <div class="card bg-gradient-to-br from-amber-500/10 to-amber-600/5 border border-amber-500/20">
          <div class="card-body p-5">
            <div class="flex items-center gap-3">
              <div class="rounded-xl bg-amber-500/15 p-2.5">
                <.icon
                  name={if @show_value, do: "hero-banknotes", else: "hero-eye-slash"}
                  class="size-5 text-amber-600 dark:text-amber-400"
                />
              </div>
              <div>
                <p class="text-xs text-base-content/50 uppercase tracking-wider font-semibold">
                  {gettext("Community Value")}
                </p>
                <p :if={@show_value} class="text-2xl font-bold">
                  {format_currency_no_decimals(@total_value)}
                </p>
                <p :if={!@show_value} class="text-sm text-base-content/40 mt-1">
                  {gettext("Available soon")}
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <%!-- Popular Stocks --%>
        <div class="card bg-base-200 border border-base-300">
          <div class="card-body p-5">
            <div class="flex items-center gap-2 mb-4">
              <.icon name="hero-fire" class="size-5 text-orange-500" />
              <h2 class="text-lg font-bold">{gettext("Popular Stocks")}</h2>
            </div>
            <div :if={@popular_stocks == []} class="py-8 text-center">
              <.icon name="hero-chart-bar" class="size-12 mx-auto text-base-content/20 mb-3" />
              <p class="text-base-content/50 text-sm">{gettext("No stocks yet")}</p>
              <p class="text-base-content/40 text-xs mt-1">
                {gettext("Share your portfolio from")}
                <a href="https://quantic.es" class="link link-primary">quantic.es</a>
              </p>
            </div>
            <div :if={@popular_stocks != []} class="space-y-2">
              <div
                :for={{stock, idx} <- Enum.with_index(@popular_stocks)}
                class="flex items-center gap-3 rounded-lg bg-base-300/50 px-3 py-2.5"
              >
                <span class={[
                  "flex items-center justify-center size-7 rounded-full text-xs font-bold",
                  rank_style(idx)
                ]}>
                  {idx + 1}
                </span>
                <.stock_logo symbol={stock.symbol} size={32} />
                <span class="font-semibold flex-1">{stock.symbol}</span>
                <div class="flex items-center gap-4 text-sm text-base-content/60">
                  <span class="flex items-center gap-1">
                    <.icon name="hero-user-group-micro" class="size-3.5" />
                    {stock.holders}
                  </span>
                  <span class="flex items-center gap-1">
                    <.icon name="hero-square-3-stack-3d-micro" class="size-3.5" />
                    {format_number(stock.total_quantity)}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- Latest Portfolios --%>
        <div class="card bg-base-200 border border-base-300">
          <div class="card-body p-5">
            <div class="flex items-center gap-2 mb-4">
              <.icon name="hero-briefcase" class="size-5 text-primary" />
              <h2 class="text-lg font-bold">{gettext("Latest Portfolios")}</h2>
            </div>
            <div :if={@portfolio_slugs == []} class="py-8 text-center">
              <.icon name="hero-briefcase" class="size-12 mx-auto text-base-content/20 mb-3" />
              <p class="text-base-content/50 text-sm">{gettext("No portfolios shared yet")}</p>
              <p class="text-base-content/40 text-xs mt-1">
                {gettext("Enable sharing in your")}
                <a href="https://quantic.es" class="link link-primary">quantic.es</a>
                {gettext("settings")}
              </p>
            </div>
            <div :if={@portfolio_slugs != []} class="space-y-2">
              <.link
                :for={slug <- @portfolio_slugs}
                navigate={~p"/p/#{slug}"}
                class="flex items-center gap-2 rounded-lg bg-base-300/50 px-3 py-2.5 hover:bg-primary/10 transition-colors group"
              >
                <span class="flex items-center justify-center size-8 rounded-full bg-primary/15 text-primary text-sm font-bold">
                  {slug |> String.first() |> String.upcase()}
                </span>
                <span class="font-medium flex-1 group-hover:text-primary transition-colors">
                  {slug}
                </span>
                <.icon
                  name="hero-arrow-right-micro"
                  class="size-4 ml-auto text-base-content/30 group-hover:text-primary transition-colors"
                />
              </.link>
            </div>
          </div>
        </div>

        <%!-- Most Visited This Week --%>
        <div class="card bg-base-200 border border-base-300">
          <div class="card-body p-5">
            <div class="flex items-center gap-2 mb-4">
              <.icon name="hero-eye" class="size-5 text-violet-500" />
              <h2 class="text-lg font-bold">{gettext("Trending This Week")}</h2>
            </div>
            <div :if={@top_visited == []} class="py-8 text-center">
              <.icon name="hero-eye" class="size-12 mx-auto text-base-content/20 mb-3" />
              <p class="text-base-content/50 text-sm">{gettext("No visits yet")}</p>
              <p class="text-base-content/40 text-xs mt-1">
                {gettext("Visit a portfolio to see it here")}
              </p>
            </div>
            <div :if={@top_visited != []} class="space-y-2">
              <.link
                :for={{entry, idx} <- Enum.with_index(@top_visited)}
                navigate={~p"/p/#{entry.slug}"}
                class="flex items-center gap-3 rounded-lg bg-base-300/50 px-3 py-2.5 hover:bg-violet-500/10 transition-colors group"
              >
                <span class={[
                  "flex items-center justify-center size-7 rounded-full text-xs font-bold",
                  rank_style(idx)
                ]}>
                  {idx + 1}
                </span>
                <span class="flex items-center justify-center size-8 rounded-full bg-primary/15 text-primary text-sm font-bold">
                  {entry.slug |> String.first() |> String.upcase()}
                </span>
                <span class="font-medium flex-1 group-hover:text-violet-500 transition-colors">
                  {entry.slug}
                </span>
                <span class="text-sm text-base-content/50 flex items-center gap-1">
                  <.icon name="hero-eye-micro" class="size-3.5" />
                  {entry.visits}
                </span>
              </.link>
            </div>
          </div>
        </div>
      </div>

      <%!-- Community yield cards (gated by cohort threshold same as total_value) --%>
      <div
        :if={@community_yoc || @community_current_yield}
        class="mt-6 grid grid-cols-1 sm:grid-cols-2 gap-4"
      >
        <div
          :if={@community_yoc}
          class="card bg-gradient-to-br from-emerald-500/10 to-emerald-600/5 border border-emerald-500/20"
        >
          <div class="card-body p-5">
            <div class="flex items-center gap-3">
              <div class="rounded-xl bg-emerald-500/15 p-2.5">
                <.icon name="hero-trending-up" class="size-5 text-emerald-600 dark:text-emerald-400" />
              </div>
              <div>
                <p class="text-xs text-base-content/50 uppercase tracking-wider font-semibold">
                  {gettext("Average Yield on Cost")}
                </p>
                <p class="text-2xl font-bold tabular-nums">{@community_yoc}%</p>
              </div>
            </div>
          </div>
        </div>

        <div
          :if={@community_current_yield}
          class="card bg-gradient-to-br from-cyan-500/10 to-cyan-600/5 border border-cyan-500/20"
        >
          <div class="card-body p-5">
            <div class="flex items-center gap-3">
              <div class="rounded-xl bg-cyan-500/15 p-2.5">
                <.icon name="hero-currency-dollar" class="size-5 text-cyan-600 dark:text-cyan-400" />
              </div>
              <div>
                <p class="text-xs text-base-content/50 uppercase tracking-wider font-semibold">
                  {gettext("Average Current Yield")}
                </p>
                <p class="text-2xl font-bold tabular-nums">{@community_current_yield}%</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Community Sectors (gated by cohort threshold same as total_value) --%>
      <div :if={@community_sectors != []} class="mt-6 card bg-base-200 border border-base-300">
        <div class="card-body p-5">
          <div class="flex items-center gap-2 mb-4">
            <.icon name="hero-chart-pie" class="size-5 text-blue-500" />
            <h2 class="text-lg font-bold">{gettext("Community Sectors")}</h2>
          </div>
          <div class="flex rounded-full overflow-hidden h-4 bg-base-300 mb-3">
            <div
              :for={{sector, idx} <- Enum.with_index(@community_sectors)}
              class={"h-full " <> sector_color(idx)}
              style={"width: #{sector.percent}%"}
              title={"#{sector.sector}: #{sector.percent}%"}
            >
            </div>
          </div>
          <ul class="flex flex-wrap gap-x-4 gap-y-2 text-sm">
            <li
              :for={{sector, idx} <- Enum.with_index(@community_sectors)}
              class="flex items-center gap-2"
            >
              <span class={"size-3 rounded-sm " <> sector_color(idx)}></span>
              <span class="font-medium">{sector.sector}</span>
              <span class="text-base-content/50 tabular-nums">{sector.percent}%</span>
            </li>
          </ul>
        </div>
      </div>

      <%!-- How It Works --%>
      <div class="mt-10 card bg-base-200 border border-base-300">
        <div class="card-body p-6">
          <h2 class="text-lg font-bold mb-4 text-center">{gettext("How It Works")}</h2>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-6 text-center">
            <div>
              <div class="rounded-full bg-primary/10 size-12 flex items-center justify-center mx-auto mb-3">
                <.icon name="hero-plus-circle" class="size-6 text-primary" />
              </div>
              <p class="font-semibold text-sm">{gettext("Build Your Portfolio")}</p>
              <p class="text-xs text-base-content/50 mt-1">
                {gettext("Track your holdings on")}
                <a
                  href="https://quantic.es"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="inline-flex items-center gap-0.5 link link-primary"
                >
                  <Layouts.quantic_logo size={12} /> quantic.es
                </a>
              </p>
            </div>
            <div>
              <div class="rounded-full bg-primary/10 size-12 flex items-center justify-center mx-auto mb-3">
                <.icon name="hero-share" class="size-6 text-primary" />
              </div>
              <p class="font-semibold text-sm">{gettext("Share It")}</p>
              <p class="text-xs text-base-content/50 mt-1">
                {gettext("Enable sharing in settings to go public")}
              </p>
            </div>
            <div>
              <div class="rounded-full bg-primary/10 size-12 flex items-center justify-center mx-auto mb-3">
                <.icon name="hero-signal" class="size-6 text-primary" />
              </div>
              <p class="font-semibold text-sm">{gettext("Live Updates")}</p>
              <p class="text-xs text-base-content/50 mt-1">
                {gettext("Portfolio changes stream in real-time")}
              </p>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp rank_style(0), do: "bg-amber-500/20 text-amber-600 dark:text-amber-400"
  defp rank_style(1), do: "bg-gray-400/20 text-gray-500 dark:text-gray-400"
  defp rank_style(2), do: "bg-orange-500/20 text-orange-600 dark:text-orange-400"
  defp rank_style(_), do: "bg-base-300 text-base-content/50"

  # Palette for the community-sector bar; rotates through 12 hues so we don't
  # repeat too quickly even on very diverse portfolios.
  @sector_colors ~w(
    bg-emerald-500 bg-blue-500 bg-amber-500 bg-purple-500 bg-rose-500
    bg-cyan-500 bg-indigo-500 bg-orange-500 bg-lime-500 bg-pink-500
    bg-teal-500 bg-slate-400
  )

  defp sector_color(index) do
    Enum.at(@sector_colors, rem(index, length(@sector_colors)))
  end

  # Currency-aware formatter. Community dashboard always passes USD; per-portfolio
  # views can pass a non-USD currency once the v2 payload's base_currency is wired
  # into them.
  @currency_symbols %{
    "USD" => "$",
    "EUR" => "€",
    "GBP" => "£",
    "JPY" => "¥",
    "CHF" => "CHF ",
    "CAD" => "C$",
    "AUD" => "A$"
  }

  defp format_currency_no_decimals(value, currency \\ "USD")

  defp format_currency_no_decimals(value, currency) when is_number(value) do
    "#{Map.get(@currency_symbols, currency, "#{currency} ")}#{trunc(value)}"
  end

  defp format_currency_no_decimals(_, currency) do
    "#{Map.get(@currency_symbols, currency, "#{currency} ")}0"
  end

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
