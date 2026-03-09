defmodule PulseWeb.Router do
  use PulseWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PulseWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PulseWeb do
    pipe_through :browser

    get "/logos/:symbol", LogoController, :show

    live "/", DashboardLive, :index
    live "/p/:slug", PortfolioLive, :show
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:pulse, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PulseWeb.Telemetry
    end
  end
end
