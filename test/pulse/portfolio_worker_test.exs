defmodule Pulse.PortfolioWorkerTest do
  use ExUnit.Case, async: false

  setup do
    for {_, pid, _, _} <- DynamicSupervisor.which_children(Pulse.PortfolioSupervisor) do
      DynamicSupervisor.terminate_child(Pulse.PortfolioSupervisor, pid)
    end

    :ok
  end

  test "starts and holds empty portfolio" do
    {:ok, _pid} = Pulse.PortfolioSupervisor.start_worker("test-worker")

    portfolio = Pulse.PortfolioWorker.get_portfolio("test-worker")
    assert portfolio.slug == "test-worker"
    assert portfolio.holdings == []
    assert portfolio.metrics == %{}
  end

  test "update_holdings computes metrics using current price" do
    {:ok, _pid} = Pulse.PortfolioSupervisor.start_worker("test-metrics")

    Pulse.PortfolioWorker.update_holdings("test-metrics", [
      %{"symbol" => "AAPL", "quantity" => 10, "avg_price" => 100.0, "price" => 150.0},
      %{"symbol" => "MSFT", "quantity" => 5, "avg_price" => 200.0, "price" => 300.0}
    ])

    Process.sleep(50)

    portfolio = Pulse.PortfolioWorker.get_portfolio("test-metrics")
    assert length(portfolio.holdings) == 2
    # 10*150 + 5*300 = 3000
    assert portfolio.metrics.total_value == 3000.0
    assert portfolio.metrics.holding_count == 2
    assert length(portfolio.metrics.allocations) == 2

    aapl = Enum.find(portfolio.metrics.allocations, fn a -> a.symbol == "AAPL" end)
    assert aapl.percentage == 50.0
    assert aapl.value == 1500.0
  end

  test "allocations reflect market value, not cost basis" do
    {:ok, _pid} = Pulse.PortfolioSupervisor.start_worker("test-market-value")

    Pulse.PortfolioWorker.update_holdings("test-market-value", [
      %{"symbol" => "AAPL", "quantity" => 10, "avg_price" => 100.0, "price" => 200.0},
      %{"symbol" => "MSFT", "quantity" => 10, "avg_price" => 100.0, "price" => 100.0}
    ])

    Process.sleep(50)

    portfolio = Pulse.PortfolioWorker.get_portfolio("test-market-value")
    # AAPL: 10*200=2000, MSFT: 10*100=1000, total=3000
    assert portfolio.metrics.total_value == 3000.0

    aapl = Enum.find(portfolio.metrics.allocations, fn a -> a.symbol == "AAPL" end)
    msft = Enum.find(portfolio.metrics.allocations, fn a -> a.symbol == "MSFT" end)
    assert aapl.percentage == 66.67
    assert msft.percentage == 33.33
  end

  test "falls back to avg_price when price is missing" do
    {:ok, _pid} = Pulse.PortfolioSupervisor.start_worker("test-fallback")

    Pulse.PortfolioWorker.update_holdings("test-fallback", [
      %{"symbol" => "AAPL", "quantity" => 10, "avg_price" => 100.0},
      %{"symbol" => "MSFT", "quantity" => 5, "avg_price" => 200.0}
    ])

    Process.sleep(50)

    portfolio = Pulse.PortfolioWorker.get_portfolio("test-fallback")
    assert portfolio.metrics.total_value == 2000.0

    aapl = Enum.find(portfolio.metrics.allocations, fn a -> a.symbol == "AAPL" end)
    assert aapl.percentage == 50.0
    assert aapl.value == 1000.0
  end

  test "broadcasts portfolio update via PubSub" do
    {:ok, _pid} = Pulse.PortfolioSupervisor.start_worker("test-pubsub")
    Phoenix.PubSub.subscribe(Pulse.PubSub, "portfolio:test-pubsub")

    Pulse.PortfolioWorker.update_holdings("test-pubsub", [
      %{"symbol" => "AAPL", "quantity" => 5, "avg_price" => 150.0}
    ])

    assert_receive {:portfolio_updated, %Pulse.PortfolioWorker{slug: "test-pubsub"}}, 1_000
  end
end
