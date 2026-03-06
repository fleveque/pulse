defmodule Pulse.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PulseWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:pulse, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Pulse.PubSub},

      # Portfolio OTP tree
      {Registry, keys: :unique, name: Pulse.PortfolioRegistry},
      {Pulse.PortfolioSupervisor, []},
      {Pulse.Store, []},
      {Pulse.Analytics, []},

      # Dashboard aggregator (must start before NATS consumer)
      Pulse.DashboardAggregator,

      # Restore persisted portfolios before NATS events arrive
      {Task, fn -> Pulse.Store.restore_all() end},

      # NATS connection and consumer
      Pulse.Nats.Connection,
      Pulse.Nats.Consumer,

      # Start to serve requests, typically the last entry
      PulseWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Pulse.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    PulseWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
