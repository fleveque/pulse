defmodule Pulse.Store do
  @moduledoc """
  DETS-backed persistence for portfolio state.

  Stores portfolio data as plain maps to avoid struct version issues
  across deploys. On application start, restores all persisted portfolios
  by starting workers and feeding them their saved holdings.
  """
  use GenServer

  require Logger

  @table :pulse_portfolios

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Persist portfolio state for a slug."
  def put(slug, %{holdings: holdings, metrics: metrics}) do
    GenServer.cast(__MODULE__, {:put, slug, %{holdings: holdings, metrics: metrics}})
  end

  @doc "Retrieve persisted state for a slug."
  def get(slug) do
    GenServer.call(__MODULE__, {:get, slug})
  end

  @doc "List all persisted portfolio entries."
  def all do
    GenServer.call(__MODULE__, :all)
  end

  @doc "Delete persisted state for a slug."
  def delete(slug) do
    GenServer.cast(__MODULE__, {:delete, slug})
  end

  @doc "Restore all persisted portfolios by starting workers and feeding holdings."
  def restore_all do
    GenServer.call(__MODULE__, :restore_all, 30_000)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    data_dir = Application.get_env(:pulse, :data_dir, "priv/data")
    File.mkdir_p!(data_dir)

    dets_path = Path.join(data_dir, "portfolios.dets") |> String.to_charlist()

    case :dets.open_file(@table, file: dets_path, type: :set) do
      {:ok, table} ->
        Logger.info("Pulse.Store opened DETS at #{dets_path}")
        {:ok, %{table: table}}

      {:error, reason} ->
        Logger.error("Failed to open DETS: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_cast({:put, slug, state}, data) do
    :dets.insert(data.table, {slug, state})
    {:noreply, data}
  end

  def handle_cast({:delete, slug}, data) do
    :dets.delete(data.table, slug)
    {:noreply, data}
  end

  @impl true
  def handle_call({:get, slug}, _from, data) do
    result =
      case :dets.lookup(data.table, slug) do
        [{^slug, state}] -> state
        [] -> nil
      end

    {:reply, result, data}
  end

  def handle_call(:all, _from, data) do
    entries =
      :dets.foldl(
        fn {slug, state}, acc -> [{slug, state} | acc] end,
        [],
        data.table
      )

    {:reply, entries, data}
  end

  def handle_call(:restore_all, _from, data) do
    entries =
      :dets.foldl(
        fn {slug, state}, acc -> [{slug, state} | acc] end,
        [],
        data.table
      )

    restored =
      Enum.reduce(entries, 0, fn {slug, state}, count ->
        case Pulse.PortfolioSupervisor.start_worker(slug) do
          {:ok, _pid} ->
            if holdings = state[:holdings],
              do: Pulse.PortfolioWorker.update_holdings(slug, holdings)

            count + 1

          {:error, {:already_started, _pid}} ->
            if holdings = state[:holdings],
              do: Pulse.PortfolioWorker.update_holdings(slug, holdings)

            count + 1

          {:error, reason} ->
            Logger.error("Failed to restore worker for #{slug}: #{inspect(reason)}")
            count
        end
      end)

    Logger.info("Restored #{restored}/#{length(entries)} portfolios from DETS")
    {:reply, {:ok, restored}, data}
  end

  @impl true
  def terminate(_reason, data) do
    :dets.close(data.table)
    :ok
  end
end
