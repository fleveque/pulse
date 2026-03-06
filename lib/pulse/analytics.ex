defmodule Pulse.Analytics do
  @moduledoc """
  Tracks portfolio page visits with weekly rollover.

  Stores visit counts in ETS for fast reads, persisted to DETS
  so data survives restarts. Resets counts at the start of each
  ISO week (Monday 00:00 UTC).
  """
  use GenServer

  require Logger

  @ets_table :pulse_analytics
  @dets_table :pulse_analytics_dets

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Record a visit to a portfolio page."
  def track_visit(slug) do
    GenServer.cast(__MODULE__, {:track_visit, slug})
  end

  @doc "Return the top N most visited portfolios this week."
  def top_visited(limit \\ 5) do
    GenServer.call(__MODULE__, {:top_visited, limit})
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    :ets.new(@ets_table, [:named_table, :public, :set])

    data_dir = Application.get_env(:pulse, :data_dir, "priv/data")
    File.mkdir_p!(data_dir)
    dets_path = Path.join(data_dir, "analytics.dets") |> String.to_charlist()

    case :dets.open_file(@dets_table, file: dets_path, type: :set) do
      {:ok, _} ->
        restore_from_dets()
        schedule_weekly_reset()
        {:ok, %{week: current_week()}}

      {:error, reason} ->
        Logger.error("Failed to open analytics DETS: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_cast({:track_visit, slug}, state) do
    count = :ets.update_counter(@ets_table, slug, {2, 1}, {slug, 0})
    :dets.insert(@dets_table, {slug, count})
    {:noreply, state}
  end

  @impl true
  def handle_call({:top_visited, limit}, _from, state) do
    results =
      :ets.tab2list(@ets_table)
      |> Enum.sort_by(fn {_slug, count} -> -count end)
      |> Enum.take(limit)
      |> Enum.map(fn {slug, count} -> %{slug: slug, visits: count} end)

    {:reply, results, state}
  end

  @impl true
  def handle_info(:weekly_reset, state) do
    new_week = current_week()

    if new_week != state.week do
      Logger.info("Analytics weekly reset (week #{new_week})")
      :ets.delete_all_objects(@ets_table)
      :dets.delete_all_objects(@dets_table)
    end

    schedule_weekly_reset()
    {:noreply, %{state | week: new_week}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    :dets.close(@dets_table)
    :ok
  end

  # Private

  defp restore_from_dets do
    :dets.foldl(
      fn {slug, count}, _acc ->
        :ets.insert(@ets_table, {slug, count})
        :ok
      end,
      :ok,
      @dets_table
    )
  end

  defp current_week do
    :calendar.iso_week_number(Date.utc_today() |> Date.to_erl())
  end

  defp schedule_weekly_reset do
    # Check every hour if we've crossed into a new week
    Process.send_after(self(), :weekly_reset, :timer.hours(1))
  end
end
