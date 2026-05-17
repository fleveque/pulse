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

  test "accepts a v2 payload map with base_currency and value_in_base" do
    {:ok, _pid} = Pulse.PortfolioSupervisor.start_worker("test-v2")

    Pulse.PortfolioWorker.update_holdings("test-v2", %{
      "version" => 2,
      "base_currency" => "EUR",
      "holdings" => [
        %{
          "symbol" => "IBE.MC",
          "quantity" => 20,
          "avg_price" => 12.0,
          "price" => 14.5,
          "currency" => "EUR",
          "value_in_base" => 290.0,
          "value_in_usd" => 319.0
        },
        %{
          "symbol" => "AAPL",
          "quantity" => 10,
          "avg_price" => 150.0,
          "price" => 175.0,
          "currency" => "USD",
          "value_in_base" => 1575.0,
          "value_in_usd" => 1750.0
        }
      ]
    })

    Process.sleep(50)

    portfolio = Pulse.PortfolioWorker.get_portfolio("test-v2")
    assert portfolio.base_currency == "EUR"
    # Sums value_in_base, not quantity * price
    assert portfolio.metrics.total_value == 1865.0
    assert portfolio.metrics.total_value_in_usd == 2069.0
  end

  test "v2 payload allocations use value_in_base for percentages" do
    {:ok, _pid} = Pulse.PortfolioSupervisor.start_worker("test-v2-alloc")

    Pulse.PortfolioWorker.update_holdings("test-v2-alloc", %{
      "version" => 2,
      "base_currency" => "USD",
      "holdings" => [
        %{"symbol" => "A", "value_in_base" => 750.0, "value_in_usd" => 750.0},
        %{"symbol" => "B", "value_in_base" => 250.0, "value_in_usd" => 250.0}
      ]
    })

    Process.sleep(50)

    portfolio = Pulse.PortfolioWorker.get_portfolio("test-v2-alloc")
    a = Enum.find(portfolio.metrics.allocations, &(&1.symbol == "A"))
    b = Enum.find(portfolio.metrics.allocations, &(&1.symbol == "B"))
    assert a.percentage == 75.0
    assert b.percentage == 25.0
  end

  test "v1 list payload still works (back-compat)" do
    {:ok, _pid} = Pulse.PortfolioSupervisor.start_worker("test-v1-compat")

    Pulse.PortfolioWorker.update_holdings("test-v1-compat", [
      %{"symbol" => "AAPL", "quantity" => 10, "avg_price" => 100.0, "price" => 150.0}
    ])

    Process.sleep(50)

    portfolio = Pulse.PortfolioWorker.get_portfolio("test-v1-compat")
    assert portfolio.metrics.total_value == 1500.0
    # In v1 we treat total_value as USD for cross-portfolio aggregation
    assert portfolio.metrics.total_value_in_usd == 1500.0
    assert portfolio.base_currency == "USD"
  end

  test "stores stats from the payload (v2.1+)" do
    {:ok, _pid} = Pulse.PortfolioSupervisor.start_worker("test-stats")

    Pulse.PortfolioWorker.update_holdings("test-stats", %{
      "version" => 2,
      "base_currency" => "USD",
      "holdings" => [%{"symbol" => "AAPL", "value_in_base" => 1000.0, "value_in_usd" => 1000.0}],
      "stats" => %{
        "yoc" => 3.2,
        "currentYield" => 2.8,
        "sectors" => [%{"sector" => "Technology", "value" => 1000.0, "percent" => 100.0}]
      }
    })

    Process.sleep(50)

    portfolio = Pulse.PortfolioWorker.get_portfolio("test-stats")
    assert portfolio.stats["yoc"] == 3.2
    assert portfolio.stats["currentYield"] == 2.8
    assert hd(portfolio.stats["sectors"])["sector"] == "Technology"
  end

  test "missing stats field stays nil (back-compat for older Rails deploys)" do
    {:ok, _pid} = Pulse.PortfolioSupervisor.start_worker("test-nostats")

    Pulse.PortfolioWorker.update_holdings("test-nostats", %{
      "version" => 2,
      "base_currency" => "USD",
      "holdings" => [%{"symbol" => "AAPL", "value_in_base" => 1000.0, "value_in_usd" => 1000.0}]
    })

    Process.sleep(50)
    portfolio = Pulse.PortfolioWorker.get_portfolio("test-nostats")
    assert portfolio.stats == nil
  end
end
