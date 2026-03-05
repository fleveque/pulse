defmodule Pulse.Nats.Consumer do
  @moduledoc """
  Consumes NATS events and dispatches them to the appropriate handlers.

  Subscribes to portfolio and stock events and routes them to
  PortfolioSupervisor/PortfolioWorker as appropriate.
  """
  use GenServer

  require Logger

  @subjects ~w(portfolio.updated portfolio.opted_in portfolio.opted_out stock.price_updated)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    env_prefix = Application.get_env(:pulse, :nats_env_prefix, "dev")
    # Delay subscription to allow NATS connection to establish
    Process.send_after(self(), {:subscribe, env_prefix}, 2_000)
    {:ok, %{subscriptions: [], env_prefix: env_prefix}}
  end

  @impl true
  def handle_info({:subscribe, env_prefix}, state) do
    if Process.whereis(:nats) do
      subscriptions =
        Enum.map(@subjects, fn subject ->
          full_subject = "#{env_prefix}.#{subject}"
          Logger.info("Subscribing to NATS subject: #{full_subject}")

          case Gnat.sub(:nats, self(), full_subject) do
            {:ok, sid} ->
              {full_subject, sid}

            {:error, reason} ->
              Logger.error("Failed to subscribe to #{full_subject}: #{inspect(reason)}")
              nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      if length(subscriptions) < length(@subjects) do
        Logger.warning("Some subscriptions failed, retrying in 5s")
        Process.send_after(self(), {:subscribe, env_prefix}, 5_000)
      end

      {:noreply, %{state | subscriptions: subscriptions}}
    else
      Logger.warning("NATS not connected, retrying subscriptions in 5s")
      Process.send_after(self(), {:subscribe, env_prefix}, 5_000)
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:msg, %{topic: topic, body: body}}, state) do
    Logger.debug("Received NATS message on #{topic}")

    case Jason.decode(body) do
      {:ok, payload} ->
        handle_event(strip_prefix(topic, state.env_prefix), payload)

      {:error, reason} ->
        Logger.error("Failed to decode NATS message: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp strip_prefix(topic, prefix) do
    String.replace_prefix(topic, "#{prefix}.", "")
  end

  defp handle_event("portfolio.opted_in", %{"slug" => slug} = payload) do
    Logger.info("Portfolio opted in: #{slug}")

    case Pulse.PortfolioSupervisor.start_worker(slug) do
      {:ok, _pid} ->
        if holdings = payload["holdings"] do
          Pulse.PortfolioWorker.update_holdings(slug, holdings)
        end

      {:error, {:already_started, _pid}} ->
        Logger.info("Worker already exists for #{slug}, updating holdings")

        if holdings = payload["holdings"] do
          Pulse.PortfolioWorker.update_holdings(slug, holdings)
        end

      {:error, reason} ->
        Logger.error("Failed to start worker for #{slug}: #{inspect(reason)}")
    end
  end

  defp handle_event("portfolio.opted_out", %{"slug" => slug}) do
    Logger.info("Portfolio opted out: #{slug}")
    Pulse.PortfolioSupervisor.stop_worker(slug)
  end

  defp handle_event("portfolio.updated", %{"slug" => slug, "holdings" => holdings}) do
    Logger.info("Portfolio updated: #{slug}")

    case Registry.lookup(Pulse.PortfolioRegistry, slug) do
      [{_pid, _}] ->
        Pulse.PortfolioWorker.update_holdings(slug, holdings)

      [] ->
        Logger.warning("No worker for #{slug}, starting one")
        Pulse.PortfolioSupervisor.start_worker(slug)
        Pulse.PortfolioWorker.update_holdings(slug, holdings)
    end
  end

  defp handle_event("stock.price_updated", %{"symbol" => symbol} = payload) do
    Logger.debug("Stock price updated: #{symbol}")
    Phoenix.PubSub.broadcast(Pulse.PubSub, "stocks", {:price_updated, payload})
  end

  defp handle_event(topic, _payload) do
    Logger.warning("Unhandled NATS event: #{topic}")
  end
end
