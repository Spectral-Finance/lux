defmodule Lux.EventMonitor.SubscriptionTest do
  use UnitCase, async: true

  alias Lux.EventMonitor.Subscription

  describe "new/1" do
    test "creates a subscription with required fields" do
      sub = Subscription.new(%{address: "0xdead", chain_id: 1})

      assert sub.address == "0xdead"
      assert sub.chain_id == 1
      assert String.starts_with?(sub.id, "sub_")
      assert sub.active == true
      assert sub.event_names == []
      assert sub.poll_interval_ms == 15_000
      assert sub.from_block == :latest
      assert sub.last_synced_block == nil
      assert sub.metadata == %{}
      assert is_integer(sub.created_at)
    end

    test "creates a subscription with all options" do
      abi = [%{"type" => "event", "name" => "Transfer"}]

      sub = Subscription.new(%{
        id: "custom_id",
        address: "0xusdc",
        chain_id: 137,
        abi: abi,
        event_names: ["Transfer", "Approval"],
        topics: ["0xtopic0"],
        filter: %{params: %{"value" => {:gt, 1000}}},
        from_block: 18_000_000,
        poll_interval_ms: 30_000,
        active: false,
        metadata: %{name: "USDC Monitor"}
      })

      assert sub.id == "custom_id"
      assert sub.chain_id == 137
      assert sub.abi == abi
      assert sub.event_names == ["Transfer", "Approval"]
      assert sub.topics == ["0xtopic0"]
      assert sub.from_block == 18_000_000
      assert sub.poll_interval_ms == 30_000
      assert sub.active == false
      assert sub.metadata == %{name: "USDC Monitor"}
    end

    test "raises on missing required fields" do
      assert_raise KeyError, fn -> Subscription.new(%{}) end
      assert_raise KeyError, fn -> Subscription.new(%{address: "0x"}) end
      assert_raise KeyError, fn -> Subscription.new(%{chain_id: 1}) end
    end
  end

  describe "update_last_synced/2" do
    test "updates the last synced block" do
      sub = Subscription.new(%{address: "0xdead", chain_id: 1})
      updated = Subscription.update_last_synced(sub, 18_000_500)
      assert updated.last_synced_block == 18_000_500
    end
  end

  describe "activate/1 and deactivate/1" do
    test "activates a subscription" do
      sub = Subscription.new(%{address: "0xdead", chain_id: 1, active: false})
      assert Subscription.activate(sub).active == true
    end

    test "deactivates a subscription" do
      sub = Subscription.new(%{address: "0xdead", chain_id: 1})
      assert Subscription.deactivate(sub).active == false
    end
  end

  describe "next_poll_from/1" do
    test "returns from_block when no synced block" do
      sub = Subscription.new(%{address: "0xdead", chain_id: 1, from_block: 18_000_000})
      assert Subscription.next_poll_from(sub) == 18_000_000
    end

    test "returns :latest when no synced block and from_block is :latest" do
      sub = Subscription.new(%{address: "0xdead", chain_id: 1})
      assert Subscription.next_poll_from(sub) == :latest
    end

    test "returns last_synced_block + 1 when synced" do
      sub =
        %{address: "0xdead", chain_id: 1, from_block: 18_000_000}
        |> Subscription.new()
        |> Subscription.update_last_synced(18_000_500)

      assert Subscription.next_poll_from(sub) == 18_000_501
    end
  end
end
