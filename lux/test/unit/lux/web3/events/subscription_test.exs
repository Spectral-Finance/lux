defmodule Lux.Web3.Events.SubscriptionTest do
  use UnitAPICase, async: true
  alias Lux.Web3.Events.Subscription
  alias Lux.Web3.Events.Decoder

  describe "new/1" do
    test "creates subscription with defaults" do
      sub = Subscription.new(%{
        chain_id: 1,
        contract_address: "0xbd3531da5cf5857e7cfaa92426877b022e612cf8",
        event_signatures: ["Transfer(address,address,uint256)"]
      })
      assert sub.chain_id == 1
      assert sub.contract_address == "0xbd3531da5cf5857e7cfaa92426877b022e612cf8"
      assert sub.event_signatures == ["Transfer(address,address,uint256)"]
      assert sub.poll_interval_ms == 5_000
      assert sub.enabled == true
      assert sub.last_synced_block == 0
      assert is_binary(sub.id)
    end
  end

  describe "from_signature/3" do
    test "creates subscription from event signature" do
      sub = Subscription.from_signature(1, "0x1234567890123456789012345678901234567890", "Transfer(address,address,uint256)")
      assert sub.chain_id == 1
      assert sub.contract_address == "0x1234567890123456789012345678901234567890"
      assert sub.event_signatures == ["Transfer(address,address,uint256)"]
    end
  end

  describe "topic_matches?/2" do
    test "matches when topic matches event signature" do
      transfer_topic = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
      sub = Subscription.new(%{event_signatures: ["Transfer(address,address,uint256)"]})
      assert Subscription.topic_matches?(sub, transfer_topic)
    end

    test "does not match unrelated topic" do
      sub = Subscription.new(%{event_signatures: ["Transfer(address,address,uint256)"]})
      refute Subscription.topic_matches?(sub, "0x0000000000000000000000000000000000000000000000000000000000000001")
    end

    test "matches multiple event signatures" do
      sub = Subscription.new(%{event_signatures: ["Transfer(address,address,uint256)", "Approval(address,address,uint256)"]})
      assert Subscription.topic_matches?(sub, "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef")
      approval_topic = Decoder.event_signature_to_topic("Approval(address,address,uint256)")
      assert Subscription.topic_matches?(sub, approval_topic)
    end
  end

  describe "block_range/1" do
    test "returns range from last_synced_block + 1" do
      sub = Subscription.new(%{last_synced_block: 100, to_block: :latest})
      assert Subscription.block_range(sub) == {101, :latest}
    end
  end

  describe "mark_synced/2" do
    test "updates last_synced_block" do
      sub = Subscription.new(%{last_synced_block: 100})
      updated = Subscription.mark_synced(sub, 500)
      assert updated.last_synced_block == 500
    end

    test "does not decrease block number" do
      sub = Subscription.new(%{last_synced_block: 500})
      updated = Subscription.mark_synced(sub, 100)
      assert updated.last_synced_block == 500
    end
  end
end
