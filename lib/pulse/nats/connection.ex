defmodule Pulse.Nats.Connection do
  @moduledoc """
  Manages the NATS connection using Gnat.

  Retries connection on failure so the rest of the application can start
  even if NATS is unavailable. Registers the connection as `:nats`.
  """
  use GenServer

  require Logger

  @retry_interval 10_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    send(self(), :connect)
    {:ok, %{connection_pid: nil}}
  end

  @impl true
  def handle_info(:connect, state) do
    settings = Application.get_env(:pulse, :nats, [])

    gnat_settings = %{
      host: Keyword.get(settings, :host, "localhost"),
      port: Keyword.get(settings, :port, 4222)
    }

    case Gnat.start_link(gnat_settings) do
      {:ok, pid} ->
        Process.register(pid, :nats)
        Logger.info("Connected to NATS at #{gnat_settings.host}:#{gnat_settings.port}")
        Process.monitor(pid)
        {:noreply, %{state | connection_pid: pid}}

      {:error, reason} ->
        Logger.warning(
          "NATS unavailable (#{inspect(reason)}), retrying in #{div(@retry_interval, 1000)}s"
        )

        Process.send_after(self(), :connect, @retry_interval)
        {:noreply, %{state | connection_pid: nil}}
    end
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, %{connection_pid: pid} = state) do
    Logger.warning(
      "NATS connection lost (#{inspect(reason)}), reconnecting in #{div(@retry_interval, 1000)}s"
    )

    Process.send_after(self(), :connect, @retry_interval)
    {:noreply, %{state | connection_pid: nil}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
