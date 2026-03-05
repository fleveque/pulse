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

  test "update_holdings computes metrics" do
    {:ok, _pid} = Pulse.PortfolioSupervisor.start_worker("test-metrics")

    Pulse.PortfolioWorker.update_holdings("test-metrics", [
      %{"symbol" => "AAPL", "quantity" => 10, "avg_price" => 100.0},
      %{"symbol" => "MSFT", "quantity" => 5, "avg_price" => 200.0}
    ])

    Process.sleep(50)

    portfolio = Pulse.PortfolioWorker.get_portfolio("test-metrics")
    assert length(portfolio.holdings) == 2
    assert portfolio.metrics.total_value == 2000.0
    assert portfolio.metrics.holding_count == 2
    assert length(portfolio.metrics.allocations) == 2

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
