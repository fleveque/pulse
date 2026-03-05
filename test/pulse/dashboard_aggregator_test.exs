defmodule Pulse.DashboardAggregatorTest do
  use ExUnit.Case, async: false

  setup do
    # Clean up any leftover workers from other tests
    for {_, pid, _, _} <- DynamicSupervisor.which_children(Pulse.PortfolioSupervisor) do
      DynamicSupervisor.terminate_child(Pulse.PortfolioSupervisor, pid)
    end

    # Force aggregator to recompute with clean state
    Pulse.DashboardAggregator.refresh()
    :ok
  end

  test "get_stats returns empty stats when no workers" do
    stats = Pulse.DashboardAggregator.get_stats()

    assert stats.portfolio_count == 0
    assert stats.total_holdings == 0
    assert stats.total_value == 0.0
    assert stats.popular_stocks == []
    assert stats.portfolio_slugs == []
  end

  test "get_stats reflects active portfolio workers" do
    {:ok, _pid} = Pulse.PortfolioSupervisor.start_worker("test-agg")

    Pulse.PortfolioWorker.update_holdings("test-agg", [
      %{"symbol" => "AAPL", "quantity" => 10, "avg_price" => 150.0},
      %{"symbol" => "MSFT", "quantity" => 5, "avg_price" => 300.0}
    ])

    # Wait for: cast processing + PubSub delivery + debounce (500ms) + recompute
    Process.sleep(800)

    stats = Pulse.DashboardAggregator.get_stats()

    assert stats.portfolio_count == 1
    assert stats.total_holdings == 2
    assert stats.total_value == 3000.0

    aapl = Enum.find(stats.popular_stocks, fn s -> s.symbol == "AAPL" end)
    assert aapl != nil
    assert aapl.holders == 1

    assert "test-agg" in stats.portfolio_slugs
  end
end
