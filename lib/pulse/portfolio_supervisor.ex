defmodule Pulse.PortfolioSupervisor do
  @moduledoc """
  DynamicSupervisor that manages PortfolioWorker processes.

  Workers are started when a user opts in to sharing their portfolio
  and stopped when they opt out.
  """
  use DynamicSupervisor

  require Logger

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a portfolio worker for the given slug.
  Returns {:ok, pid} or {:error, reason}.
  """
  def start_worker(slug) do
    Logger.info("Starting portfolio worker for slug: #{slug}")

    DynamicSupervisor.start_child(__MODULE__, {Pulse.PortfolioWorker, slug})
  end

  @doc """
  Stops the portfolio worker for the given slug.
  """
  def stop_worker(slug) do
    case Registry.lookup(Pulse.PortfolioRegistry, slug) do
      [{pid, _}] ->
        Logger.info("Stopping portfolio worker for slug: #{slug}")
        DynamicSupervisor.terminate_child(__MODULE__, pid)

      [] ->
        Logger.warning("No portfolio worker found for slug: #{slug}")
        {:error, :not_found}
    end
  end
end
