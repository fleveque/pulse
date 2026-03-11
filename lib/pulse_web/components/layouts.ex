defmodule PulseWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use PulseWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col">
      <header class="navbar bg-base-200 border-b border-base-300 px-4 sm:px-6 lg:px-8">
        <div class="flex-1">
          <a href="/" class="flex items-center gap-2">
            <.pulse_logo size={28} />
            <span class="text-lg font-bold tracking-tight">Pulse</span>
            <span class="badge badge-sm badge-ghost font-mono">beta</span>
          </a>
        </div>
        <div class="flex-none">
          <ul class="flex items-center gap-2">
            <li>
              <a href="https://quantic.es" class="btn btn-ghost btn-sm">quantic.es</a>
            </li>
            <li>
              <.language_toggle />
            </li>
            <li>
              <.theme_toggle />
            </li>
          </ul>
        </div>
      </header>

      <main class="flex-1 px-4 py-8 sm:px-6 lg:px-8">
        <div class="mx-auto max-w-5xl">
          {render_slot(@inner_block)}
        </div>
      </main>

      <footer class="border-t border-base-300 bg-base-200 px-4 py-6 sm:px-6 sm:py-8 lg:px-8">
        <div class="mx-auto max-w-5xl flex flex-col sm:flex-row items-center justify-between gap-4">
          <div class="flex items-center gap-2">
            <.pulse_logo size={20} />
            <span class="font-bold tracking-tight">Pulse</span>
            <span class="text-base-content/50 text-sm">{gettext("Community portfolios")}</span>
          </div>
          <div class="text-center sm:text-right text-xs sm:text-sm text-base-content/60">
            <p>
              {gettext("Part of")}
              <a href="https://quantic.es" class="hover:underline font-medium text-base-content/80">
                quantic.es
              </a>
              &middot; {gettext("Built with Elixir and Phoenix LiveView")}
            </p>
            <p class="mt-1">
              &copy; {DateTime.utc_now().year}
              <a
                href="https://leveque.es"
                target="_blank"
                rel="noopener noreferrer"
                class="hover:underline"
              >
                Francesc Leveque
              </a>
            </p>
          </div>
        </div>
      </footer>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  attr :size, :integer, default: 32

  def quantic_logo(assigns) do
    ~H"""
    <svg width={@size} height={@size} viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id={"emerald-grad-#{@size}"} x1="0%" y1="100%" x2="100%" y2="0%">
          <stop offset="0%" style="stop-color:#047857" />
          <stop offset="100%" style="stop-color:#10b981" />
        </linearGradient>
      </defs>
      <circle cx="256" cy="256" r="240" fill={"url(#emerald-grad-#{@size})"} />
      <rect x="120" y="280" width="60" height="100" rx="8" fill="white" opacity="0.9" />
      <rect x="200" y="220" width="60" height="160" rx="8" fill="white" opacity="0.9" />
      <rect x="280" y="160" width="60" height="220" rx="8" fill="white" opacity="0.9" />
      <path
        d="M380 140 L380 260 M380 140 L340 180 M380 140 L420 180"
        stroke="white"
        stroke-width="24"
        stroke-linecap="round"
        stroke-linejoin="round"
        fill="none"
        opacity="0.95"
      />
    </svg>
    """
  end

  attr :size, :integer, default: 32

  def pulse_logo(assigns) do
    ~H"""
    <svg width={@size} height={@size} viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id={"purple-grad-#{@size}"} x1="0%" y1="100%" x2="100%" y2="0%">
          <stop offset="0%" style="stop-color:#7c3aed" />
          <stop offset="100%" style="stop-color:#a78bfa" />
        </linearGradient>
      </defs>
      <circle cx="256" cy="256" r="240" fill={"url(#purple-grad-#{@size})"} />
      <polyline
        points="80,296 160,296 200,176 248,376 296,136 344,336 384,216 432,296"
        stroke="white"
        stroke-width="28"
        stroke-linecap="round"
        stroke-linejoin="round"
        fill="none"
        opacity="0.95"
      />
    </svg>
    """
  end

  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end

  def language_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <button
        class="flex px-2 py-1.5 cursor-pointer text-xs font-semibold opacity-75 hover:opacity-100"
        phx-click={JS.dispatch("phx:set-locale")}
        data-phx-locale="en"
      >
        EN
      </button>
      <button
        class="flex px-2 py-1.5 cursor-pointer text-xs font-semibold opacity-75 hover:opacity-100"
        phx-click={JS.dispatch("phx:set-locale")}
        data-phx-locale="es"
      >
        ES
      </button>
    </div>
    """
  end
end
