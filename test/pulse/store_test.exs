defmodule Pulse.StoreTest do
  use ExUnit.Case, async: false

  setup do
    # Clean up all entries before each test
    for {slug, _state} <- Pulse.Store.all() do
      Pulse.Store.delete(slug)
    end

    # Also clean up any workers left from previous tests
    for {_, pid, _, _} <- DynamicSupervisor.which_children(Pulse.PortfolioSupervisor) do
      DynamicSupervisor.terminate_child(Pulse.PortfolioSupervisor, pid)
    end

    :ok
  end

  describe "put/2 and get/1" do
    test "persists and retrieves portfolio state" do
      state = %{
        holdings: [%{"symbol" => "AAPL", "quantity" => 10, "avg_price" => 150.0}],
        base_currency: "USD",
        stats: %{"yoc" => 4.5, "currentYield" => 3.2}
      }

      Pulse.Store.put("alice", state)
      Process.sleep(50)

      assert Pulse.Store.get("alice") == state
    end

    test "extracts only persistable fields, dropping metrics and other transient keys" do
      Pulse.Store.put("alice", %{
        holdings: [%{"symbol" => "AAPL"}],
        metrics: %{total_value: 1500.0},
        slug: "alice",
        base_currency: "EUR",
        stats: nil
      })

      Process.sleep(50)

      assert Pulse.Store.get("alice") == %{
               holdings: [%{"symbol" => "AAPL"}],
               base_currency: "EUR",
               stats: nil
             }
    end

    test "returns nil for unknown slug" do
      assert Pulse.Store.get("nonexistent") == nil
    end

    test "overwrites existing entry" do
      state1 = %{holdings: [%{"symbol" => "AAPL"}], base_currency: "USD", stats: nil}
      state2 = %{holdings: [%{"symbol" => "MSFT"}], base_currency: "USD", stats: nil}

      Pulse.Store.put("bob", state1)
      Process.sleep(50)
      Pulse.Store.put("bob", state2)
      Process.sleep(50)

      assert Pulse.Store.get("bob") == state2
    end
  end

  describe "all/0" do
    test "returns all persisted entries" do
      Pulse.Store.put("alice", %{holdings: []})
      Pulse.Store.put("bob", %{holdings: []})
      Process.sleep(50)

      entries = Pulse.Store.all()
      slugs = Enum.map(entries, fn {slug, _} -> slug end) |> Enum.sort()

      assert slugs == ["alice", "bob"]
    end

    test "returns empty list when no entries" do
      assert Pulse.Store.all() == []
    end
  end

  describe "delete/1" do
    test "removes a persisted entry" do
      Pulse.Store.put("alice", %{holdings: []})
      Process.sleep(50)
      assert Pulse.Store.get("alice") != nil

      Pulse.Store.delete("alice")
      Process.sleep(50)
      assert Pulse.Store.get("alice") == nil
    end

    test "is a no-op for unknown slug" do
      Pulse.Store.delete("nonexistent")
      Process.sleep(50)
      assert Pulse.Store.all() == []
    end
  end

  describe "restore_all/0" do
    test "starts workers for all persisted portfolios" do
      holdings = [%{"symbol" => "AAPL", "quantity" => 10, "avg_price" => 150.0}]
      Pulse.Store.put("restore-test", %{holdings: holdings})
      Process.sleep(50)

      assert Registry.lookup(Pulse.PortfolioRegistry, "restore-test") == []

      {:ok, restored} = Pulse.Store.restore_all()
      assert restored == 1

      Process.sleep(100)

      assert [{_pid, _}] = Registry.lookup(Pulse.PortfolioRegistry, "restore-test")
      portfolio = Pulse.PortfolioWorker.get_portfolio("restore-test")
      assert length(portfolio.holdings) == 1

      Pulse.PortfolioSupervisor.stop_worker("restore-test")
    end

    test "rehydrates base_currency and stats so dashboards survive restarts" do
      Pulse.Store.put("restore-stats", %{
        holdings: [%{"symbol" => "AAPL", "value_in_base" => 1000.0, "value_in_usd" => 1000.0}],
        base_currency: "EUR",
        stats: %{
          "yoc" => 4.5,
          "currentYield" => 3.2,
          "sectors" => [%{"sector" => "Technology", "percent" => 100.0}]
        }
      })

      Process.sleep(50)

      {:ok, _} = Pulse.Store.restore_all()
      Process.sleep(100)

      portfolio = Pulse.PortfolioWorker.get_portfolio("restore-stats")
      assert portfolio.base_currency == "EUR"
      assert portfolio.stats["yoc"] == 4.5
      assert portfolio.stats["currentYield"] == 3.2
      assert [%{"sector" => "Technology"}] = portfolio.stats["sectors"]

      Pulse.PortfolioSupervisor.stop_worker("restore-stats")
    end
  end
end
