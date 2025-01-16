defmodule Lux.Engine.SubscriptionRegistryTest do
  use ExUnit.Case, async: true
  alias Lux.Engine.{Subscription, SubscriptionRegistry}

  setup context do
    table_name = context.test |> Atom.to_string() |> String.to_atom()
    table_ref = SubscriptionRegistry.init(table_name)
    on_exit(fn -> SubscriptionRegistry.cleanup(table_ref) end)
    {:ok, %{table: table_ref}}
  end

  describe "registration" do
    test "can register a simple subscription", %{table: table} do
      sub = Subscription.new(%{type: "test.event"}, "specter1")
      assert :ok = SubscriptionRegistry.register(table, sub)
    end

    test "can register multiple subscriptions for same specter", %{table: table} do
      sub1 = Subscription.new(%{type: "test.event1"}, "specter1")
      sub2 = Subscription.new(%{type: "test.event2"}, "specter1")

      SubscriptionRegistry.register(table, sub1)
      SubscriptionRegistry.register(table, sub2)

      # Both patterns should be findable
      signal1 = %{type: "test.event1"}
      signal2 = %{type: "test.event2"}

      assert ["specter1"] = SubscriptionRegistry.find_matching_specters(table, signal1)
      assert ["specter1"] = SubscriptionRegistry.find_matching_specters(table, signal2)
    end
  end

  describe "pattern matching" do
    test "matches exact patterns", %{table: table} do
      sub = Subscription.new(%{type: "test.event", priority: "high"}, "specter1")
      SubscriptionRegistry.register(table, sub)

      matching_signal = %{type: "test.event", priority: "high"}
      non_matching_signal = %{type: "test.event", priority: "low"}

      assert ["specter1"] = SubscriptionRegistry.find_matching_specters(table, matching_signal)
      assert [] = SubscriptionRegistry.find_matching_specters(table, non_matching_signal)
    end

    test "matches subset of signal fields", %{table: table} do
      sub = Subscription.new(%{type: "test.event"}, "specter1")
      SubscriptionRegistry.register(table, sub)

      signal_with_extra = %{
        type: "test.event",
        priority: "high",
        timestamp: "2024-01-01"
      }

      assert ["specter1"] = SubscriptionRegistry.find_matching_specters(table, signal_with_extra)
    end

    test "matches multiple specters", %{table: table} do
      sub1 = Subscription.new(%{type: "test.event"}, "specter1")
      sub2 = Subscription.new(%{type: "test.event"}, "specter2")

      SubscriptionRegistry.register(table, sub1)
      SubscriptionRegistry.register(table, sub2)

      signal = %{type: "test.event"}

      matching_specters = SubscriptionRegistry.find_matching_specters(table, signal)
      assert length(matching_specters) == 2
      assert "specter1" in matching_specters
      assert "specter2" in matching_specters
    end
  end

  describe "unregistration" do
    test "can unregister all subscriptions for a specter", %{table: table} do
      sub1 = Subscription.new(%{type: "test.event1"}, "specter1")
      sub2 = Subscription.new(%{type: "test.event2"}, "specter1")

      SubscriptionRegistry.register(table, sub1)
      SubscriptionRegistry.register(table, sub2)

      SubscriptionRegistry.unregister_specter(table, "specter1")

      signal = %{type: "test.event1"}
      assert [] = SubscriptionRegistry.find_matching_specters(table, signal)
    end

    test "unregistering one specter doesn't affect others", %{table: table} do
      sub1 = Subscription.new(%{type: "test.event"}, "specter1")
      sub2 = Subscription.new(%{type: "test.event"}, "specter2")

      SubscriptionRegistry.register(table, sub1)
      SubscriptionRegistry.register(table, sub2)

      SubscriptionRegistry.unregister_specter(table, "specter1")

      signal = %{type: "test.event"}
      assert ["specter2"] = SubscriptionRegistry.find_matching_specters(table, signal)
    end
  end
end
