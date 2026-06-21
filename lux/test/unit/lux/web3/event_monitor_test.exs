defmodule Lux.Web3.EventMonitorTest do
  use UnitCase, async: false

  alias Lux.Web3.EventMonitor

  @usdt_address "0xdAC17F958D2ee523a2206206994597C13D831ec7"
  @transfer_sig "Transfer(address,address,uint256)"

  setup do
    # Start a unique EventMonitor for each test to avoid conflicts
    name = :"event_monitor_#{System.unique_integer([:positive])}"
    {:ok, pid} = EventMonitor.start_link(name: name, poll_interval: 60_000)
    %{server: name, pid: pid}
  end

  describe "subscribe/2" do
    test "subscribes to contract events", %{server: server} do
      result =
        EventMonitor.subscribe(
          %{
            id: "test-sub",
            contract_address: @usdt_address,
            event_signatures: [@transfer_sig],
            chain_id: 1
          },
          server
        )

      assert result == :ok
    end

    test "returns error when missing required fields", %{server: server} do
      {:error, msg} = EventMonitor.subscribe(%{id: "test"}, server)
      assert String.contains?(msg, "contract_address")
    end

    test "returns error when missing id", %{server: server} do
      {:error, msg} =
        EventMonitor.subscribe(
          %{contract_address: @usdt_address},
          server
        )

      assert String.contains?(msg, "id")
    end
  end

  describe "unsubscribe/2" do
    test "unsubscribes from contract events", %{server: server} do
      EventMonitor.subscribe(
        %{id: "test-sub", contract_address: @usdt_address},
        server
      )

      result = EventMonitor.unsubscribe("test-sub", server)
      assert result == :ok

      # Events should no longer be found
      assert {:error, :not_found} == EventMonitor.get_events("test-sub", server)
    end
  end

  describe "get_events/2" do
    test "returns empty list for new subscription", %{server: server} do
      EventMonitor.subscribe(
        %{id: "test-sub", contract_address: @usdt_address},
        server
      )

      {:ok, events} = EventMonitor.get_events("test-sub", server)
      assert events == []
    end

    test "returns error for unknown subscription", %{server: server} do
      assert {:error, :not_found} == EventMonitor.get_events("nonexistent", server)
    end
  end

  describe "query_events/3" do
    test "returns empty list for new subscription with filter", %{server: server} do
      EventMonitor.subscribe(
        %{id: "test-sub", contract_address: @usdt_address},
        server
      )

      {:ok, events} =
        EventMonitor.query_events(
          "test-sub",
          %{min_block: 0, max_block: 999_999_999},
          server
        )

      assert events == []
    end

    test "returns error for unknown subscription", %{server: server} do
      assert {:error, :not_found} ==
               EventMonitor.query_events("nonexistent", %{}, server)
    end
  end

  describe "list_subscriptions/1" do
    test "returns empty list when no subscriptions", %{server: server} do
      subs = EventMonitor.list_subscriptions(server)
      assert subs == []
    end

    test "returns list of active subscriptions", %{server: server} do
      EventMonitor.subscribe(
        %{id: "sub-1", contract_address: @usdt_address, chain_id: 1},
        server
      )

      EventMonitor.subscribe(
        %{id: "sub-2", contract_address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", chain_id: 1},
        server
      )

      subs = EventMonitor.list_subscriptions(server)
      assert length(subs) == 2
      ids = Enum.map(subs, & &1.id)
      assert "sub-1" in ids
      assert "sub-2" in ids
    end

    test "sanitizes callback from subscription list", %{server: server} do
      EventMonitor.subscribe(
        %{
          id: "sub-cb",
          contract_address: @usdt_address,
          callback: fn _event -> :ok end
        },
        server
      )

      [sub] = EventMonitor.list_subscriptions(server)
      refute Map.has_key?(sub, :callback)
    end
  end

  describe "status/1" do
    test "returns monitor status", %{server: server} do
      status = EventMonitor.status(server)
      assert status.subscription_count == 0
      assert status.total_events == 0
      assert is_integer(status.poll_interval)
    end

    test "returns updated status after subscriptions", %{server: server} do
      EventMonitor.subscribe(
        %{id: "sub-1", contract_address: @usdt_address},
        server
      )

      status = EventMonitor.status(server)
      assert status.subscription_count == 1
      assert length(status.subscriptions) == 1

      [sub_status] = status.subscriptions
      assert sub_status.id == "sub-1"
      assert sub_status.event_count == 0
    end
  end

  describe "multiple subscriptions" do
    test "manages multiple independent subscriptions", %{server: server} do
      for i <- 1..5 do
        EventMonitor.subscribe(
          %{
            id: "sub-#{i}",
            contract_address: @usdt_address,
            event_signatures: [@transfer_sig],
            chain_id: 1
          },
          server
        )
      end

      subs = EventMonitor.list_subscriptions(server)
      assert length(subs) == 5

      # Unsubscribe one
      EventMonitor.unsubscribe("sub-3", server)
      subs = EventMonitor.list_subscriptions(server)
      assert length(subs) == 4
      refute "sub-3" in Enum.map(subs, & &1.id)
    end
  end
end
