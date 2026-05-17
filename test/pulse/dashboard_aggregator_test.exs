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

  test "community_sectors aggregates sector breakdown across workers, weighted by USD value" do
    {:ok, _} = Pulse.PortfolioSupervisor.start_worker("agg-sec-a")
    {:ok, _} = Pulse.PortfolioSupervisor.start_worker("agg-sec-b")

    # Worker A: $1000 portfolio, 100% Technology
    Pulse.PortfolioWorker.update_holdings("agg-sec-a", %{
      "version" => 2,
      "base_currency" => "USD",
      "holdings" => [%{"symbol" => "AAPL", "value_in_base" => 1000.0, "value_in_usd" => 1000.0}],
      "stats" => %{"sectors" => [%{"sector" => "Technology", "percent" => 100.0}]}
    })

    # Worker B: $500 portfolio, 50% Energy / 50% Technology
    Pulse.PortfolioWorker.update_holdings("agg-sec-b", %{
      "version" => 2,
      "base_currency" => "USD",
      "holdings" => [%{"symbol" => "REP.MC", "value_in_base" => 500.0, "value_in_usd" => 500.0}],
      "stats" => %{
        "sectors" => [
          %{"sector" => "Energy", "percent" => 50.0},
          %{"sector" => "Technology", "percent" => 50.0}
        ]
      }
    })

    Process.sleep(800)

    stats = Pulse.DashboardAggregator.get_stats()
    sectors = stats.community_sectors

    # Technology: 1000 (A) + 250 (B half of 500) = 1250 → 83.3% of $1500 total
    tech = Enum.find(sectors, &(&1.sector == "Technology"))
    assert_in_delta(tech.percent, 83.3, 0.1)
    # Energy: 250 → 16.7%
    energy = Enum.find(sectors, &(&1.sector == "Energy"))
    assert_in_delta(energy.percent, 16.7, 0.1)
  end

  test "community_sectors is empty when no worker has stats" do
    {:ok, _} = Pulse.PortfolioSupervisor.start_worker("agg-no-stats")

    Pulse.PortfolioWorker.update_holdings("agg-no-stats", [
      %{"symbol" => "AAPL", "quantity" => 10, "avg_price" => 100.0, "price" => 150.0}
    ])

    Process.sleep(800)
    stats = Pulse.DashboardAggregator.get_stats()
    assert stats.community_sectors == []
  end

  test "community_yoc and community_current_yield average across workers with stats" do
    {:ok, _} = Pulse.PortfolioSupervisor.start_worker("agg-yld-a")
    {:ok, _} = Pulse.PortfolioSupervisor.start_worker("agg-yld-b")

    Pulse.PortfolioWorker.update_holdings("agg-yld-a", %{
      "version" => 2,
      "base_currency" => "USD",
      "holdings" => [%{"symbol" => "AAPL", "value_in_base" => 1000.0, "value_in_usd" => 1000.0}],
      "stats" => %{"yoc" => 4.0, "currentYield" => 3.0}
    })

    Pulse.PortfolioWorker.update_holdings("agg-yld-b", %{
      "version" => 2,
      "base_currency" => "USD",
      "holdings" => [%{"symbol" => "MSFT", "value_in_base" => 500.0, "value_in_usd" => 500.0}],
      "stats" => %{"yoc" => 6.0, "currentYield" => 5.0}
    })

    Process.sleep(800)

    stats = Pulse.DashboardAggregator.get_stats()
    assert stats.community_yoc == 5.0
    assert stats.community_current_yield == 4.0
  end

  test "community_yoc is nil when no worker has stats" do
    {:ok, _} = Pulse.PortfolioSupervisor.start_worker("agg-no-yld")

    Pulse.PortfolioWorker.update_holdings("agg-no-yld", [
      %{"symbol" => "AAPL", "quantity" => 10, "avg_price" => 100.0, "price" => 150.0}
    ])

    Process.sleep(800)

    stats = Pulse.DashboardAggregator.get_stats()
    assert stats.community_yoc == nil
    assert stats.community_current_yield == nil
  end

  test "community total sums value_in_usd across mixed-currency workers" do
    {:ok, _pid} = Pulse.PortfolioSupervisor.start_worker("test-agg-eur")
    {:ok, _pid} = Pulse.PortfolioSupervisor.start_worker("test-agg-usd")

    # Each user's portfolio is in their preferred base, but value_in_usd lets the
    # community dashboard sum them as a single USD figure.
    Pulse.PortfolioWorker.update_holdings("test-agg-eur", %{
      "version" => 2,
      "base_currency" => "EUR",
      "holdings" => [
        %{"symbol" => "IBE.MC", "value_in_base" => 1000.0, "value_in_usd" => 1100.0}
      ]
    })

    Pulse.PortfolioWorker.update_holdings("test-agg-usd", %{
      "version" => 2,
      "base_currency" => "USD",
      "holdings" => [
        %{"symbol" => "AAPL", "value_in_base" => 500.0, "value_in_usd" => 500.0}
      ]
    })

    Process.sleep(800)

    stats = Pulse.DashboardAggregator.get_stats()
    # 1100 (EUR portfolio in USD) + 500 (USD portfolio) = 1600
    assert stats.total_value == 1600.0
  end
end
