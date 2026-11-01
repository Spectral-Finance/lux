defmodule Lux.Web3.EventMonitor.SubscriptionManagerTest do
  use ExUnit.Case, async: false

  alias Lux.Web3.EventMonitor.SubscriptionManager
  alias Lux.Web3.EventMonitor.Schemas.MonitoredEvent

  setup do
    # Start isolated GenServer instance for testing
    server_name = :"sub_mgr_test_#{System.unique_integer([:positive])}"
    {:ok, pid} = SubscriptionManager.start_link(name: server_name)
    %{server: server_name, pid: pid}
  end

  describe "Subscription lifecycle" do
    test "creates, retrieves, pauses, resumes, and deletes subscription", %{server: server} do
      attrs = %{
        name: "Test Sub",
        chain: :polygon,
        chain_id: 137,
        contract_address: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
        event_name: "Transfer",
        topic0: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
      }

      {:ok, sub} = SubscriptionManager.create_subscription(server, attrs)
      assert sub.name == "Test Sub"
      assert sub.contract_address == "0x2791bca1f2de4661ed88a30c99a7a9449aa84174"
      assert sub.status == :active

      # Get
      {:ok, fetched} = SubscriptionManager.get_subscription(server, sub.id)
      assert fetched.id == sub.id

      # Pause
      {:ok, paused} = SubscriptionManager.pause_subscription(server, sub.id)
      assert paused.status == :paused

      # Resume
      {:ok, resumed} = SubscriptionManager.resume_subscription(server, sub.id)
      assert resumed.status == :active

      # List
      list = SubscriptionManager.list_subscriptions(server)
      assert length(list) == 1

      # Delete
      assert SubscriptionManager.delete_subscription(server, sub.id) == :ok
      assert SubscriptionManager.get_subscription(server, sub.id) == {:error, :not_found}
    end

    test "matches event against registered subscriptions", %{server: server} do
      {:ok, sub} =
        SubscriptionManager.create_subscription(server, %{
          name: "ETH Sub",
          chain: :ethereum,
          chain_id: 1,
          contract_address: "0xdac17f958d2ee523a2206206994597c13d831ec7",
          topic0: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
        })

      event = %MonitoredEvent{
        id: "evt_1",
        subscription_id: "any",
        chain_id: 1,
        chain: :ethereum,
        contract_address: "0xdac17f958d2ee523a2206206994597c13d831ec7",
        tx_hash: "0x123",
        block_number: 100,
        topics: ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"]
      }

      matched = SubscriptionManager.match_event(server, event)
      assert length(matched) == 1
      assert hd(matched).id == sub.id
    end
  end
end
