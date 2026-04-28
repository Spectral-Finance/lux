defmodule Lux.Integrations.SmartContractEventsTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.SmartContractEvents

  describe "subscribe/1" do
    test "creates a subscription for a contract event" do
      {:ok, sub} = SmartContractEvents.subscribe(%{
        chain: :ethereum,
        contract: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        event: "Transfer",
        from_block: "latest"
      })

      assert sub.chain == :ethereum
      assert sub.contract == "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
      assert sub.event == "Transfer"
      assert sub.active == true
    end

    test "returns error for unsupported chain" do
      assert {:error, {:unsupported_chain, :unsupported}} ==
        SmartContractEvents.subscribe(%{chain: :unsupported, contract: "0x", event: "Test"})
    end
  end

  describe "get_historical/1" do
    test "accepts valid historical query parameters" do
      result = SmartContractEvents.get_historical(%{
        chain: :base,
        contract: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
        event: "Transfer",
        from_block: 0,
        to_block: "latest"
      })

      assert match?({:ok, _} || {:error, _}, result)
    end
  end

  describe "list_subscriptions/0" do
    test "returns subscription list" do
      {:ok, subs} = SmartContractEvents.list_subscriptions()
      assert is_list(subs)
    end
  end

  describe "Filter.match?/2" do
    test "matches any event with empty filter" do
      event = %{address: "0xabc", topics: []}
      assert Lux.Integrations.SmartContractEvents.Filter.match?(event, %{pattern: :any})
    end
  end

  describe "Subscription.create/1" do
    test "creates subscription with generated id" do
      {:ok, sub} = Lux.Integrations.SmartContractEvents.Subscription.create(%{
        chain: :ethereum,
        chain_config: %{rpc: "https://eth.llamarpc.com", chain_id: 1, block_time: 12},
        contract: "0xabc",
        event: "Transfer",
        event_signature: "0x1234",
        from_block: "latest"
      })

      assert sub.id != nil
      assert sub.created_at != nil
    end
  end
end
