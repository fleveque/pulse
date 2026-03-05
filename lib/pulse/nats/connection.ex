defmodule Pulse.Nats.Connection do
  @moduledoc """
  Manages the NATS connection using Gnat.

  Wraps Gnat.ConnectionSupervisor in a task that retries on failure,
  so the rest of the application can start even if NATS is unavailable.
  """
  use GenServer

  require Logger

  @retry_interval 5_000

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
    connection_settings = Application.get_env(:pulse, :nats, [])

    gnat_settings = %{
      name: :nats,
      connection_settings: [
        %{
          host: Keyword.get(connection_settings, :host, "localhost"),
          port: Keyword.get(connection_settings, :port, 4222)
        }
      ]
    }

    case Gnat.ConnectionSupervisor.start_link(gnat_settings) do
      {:ok, pid} ->
        Logger.info("Connected to NATS")
        Process.monitor(pid)
        {:noreply, %{state | connection_pid: pid}}

      {:error, reason} ->
        Logger.warning(
          "Failed to connect to NATS: #{inspect(reason)}, retrying in #{@retry_interval}ms"
        )

        Process.send_after(self(), :connect, @retry_interval)
        {:noreply, %{state | connection_pid: nil}}
    end
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, %{connection_pid: pid} = state) do
    Logger.warning(
      "NATS connection lost: #{inspect(reason)}, reconnecting in #{@retry_interval}ms"
    )

    Process.send_after(self(), :connect, @retry_interval)
    {:noreply, %{state | connection_pid: nil}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
