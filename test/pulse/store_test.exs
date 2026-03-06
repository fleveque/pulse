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
        metrics: %{total_value: 1500.0}
      }

      Pulse.Store.put("alice", state)
      # Give the cast time to process
      Process.sleep(50)

      assert Pulse.Store.get("alice") == state
    end

    test "returns nil for unknown slug" do
      assert Pulse.Store.get("nonexistent") == nil
    end

    test "overwrites existing entry" do
      state1 = %{holdings: [%{"symbol" => "AAPL"}], metrics: %{}}
      state2 = %{holdings: [%{"symbol" => "MSFT"}], metrics: %{}}

      Pulse.Store.put("bob", state1)
      Process.sleep(50)
      Pulse.Store.put("bob", state2)
      Process.sleep(50)

      assert Pulse.Store.get("bob") == state2
    end
  end

  describe "all/0" do
    test "returns all persisted entries" do
      Pulse.Store.put("alice", %{holdings: [], metrics: %{}})
      Pulse.Store.put("bob", %{holdings: [], metrics: %{}})
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
      Pulse.Store.put("alice", %{holdings: [], metrics: %{}})
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
      Pulse.Store.put("restore-test", %{holdings: holdings, metrics: %{}})
      Process.sleep(50)

      # Ensure no worker exists
      assert Registry.lookup(Pulse.PortfolioRegistry, "restore-test") == []

      {:ok, restored} = Pulse.Store.restore_all()
      assert restored == 1

      # Give the worker time to process the update_holdings cast
      Process.sleep(100)

      # Worker should now exist with holdings
      assert [{_pid, _}] = Registry.lookup(Pulse.PortfolioRegistry, "restore-test")
      portfolio = Pulse.PortfolioWorker.get_portfolio("restore-test")
      assert length(portfolio.holdings) == 1

      # Clean up
      Pulse.PortfolioSupervisor.stop_worker("restore-test")
    end
  end
end
