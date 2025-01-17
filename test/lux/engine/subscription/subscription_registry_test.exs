defmodule Lux.Engine.SubscriptionRegistryTest do
  use ExUnit.Case
  alias Lux.Engine.SubscriptionRegistry
  alias Lux.Engine.Subscription.Pattern

  setup %{test: test_name} do
    registry_name = :"test_registry_#{test_name}"
    test_registry = :"#{registry_name}_registry"

    start_supervised!({Registry, keys: :unique, name: test_registry})
    start_supervised!({SubscriptionRegistry, name: {test_registry, registry_name}})

    %{registry: {test_registry, registry_name}}
  end

  describe "register/3" do
    test "registers a pattern for a specter", %{registry: registry} do
      pattern = Pattern.new(%{type: "test.event"})
      assert :ok = SubscriptionRegistry.register(registry, "specter1", pattern)
    end

    test "allows multiple patterns for different specters", %{registry: registry} do
      pattern1 = Pattern.new(%{type: "test.event1"})
      pattern2 = Pattern.new(%{type: "test.event2"})

      assert :ok = SubscriptionRegistry.register(registry, "specter1", pattern1)
      assert :ok = SubscriptionRegistry.register(registry, "specter2", pattern2)
    end

    test "updates existing pattern for same specter", %{registry: registry} do
      pattern1 = Pattern.new(%{type: "test.event1"})
      pattern2 = Pattern.new(%{type: "test.event2"})

      SubscriptionRegistry.register(registry, "specter1", pattern1)
      SubscriptionRegistry.register(registry, "specter1", pattern2)

      # Only pattern2 should match now
      signal1 = %{type: "test.event1"}
      signal2 = %{type: "test.event2"}

      assert [] = SubscriptionRegistry.find_matching_specters(registry, signal1)
      assert ["specter1"] = SubscriptionRegistry.find_matching_specters(registry, signal2)
    end
  end

  describe "unregister/2" do
    test "removes all patterns for a specter", %{registry: registry} do
      pattern = Pattern.new(%{type: "test.event"})
      SubscriptionRegistry.register(registry, "specter1", pattern)

      assert :ok = SubscriptionRegistry.unregister(registry, "specter1")

      signal = %{type: "test.event"}
      assert [] = SubscriptionRegistry.find_matching_specters(registry, signal)
    end

    test "returns ok even if specter doesn't exist", %{registry: registry} do
      assert :ok = SubscriptionRegistry.unregister(registry, "nonexistent")
    end
  end

  describe "find_matching_specters/2" do
    test "finds specters with exact matching patterns", %{registry: registry} do
      pattern = Pattern.new(%{type: "test.event", value: 42})
      SubscriptionRegistry.register(registry, "specter1", pattern)

      signal = %{type: "test.event", value: 42}
      assert ["specter1"] = SubscriptionRegistry.find_matching_specters(registry, signal)
    end

    test "finds specters with wildcard patterns", %{registry: registry} do
      pattern = Pattern.new(%{type: "test.*", value: "*"})
      SubscriptionRegistry.register(registry, "specter1", pattern)

      signal = %{type: "test.event", value: "anything"}
      assert ["specter1"] = SubscriptionRegistry.find_matching_specters(registry, signal)
    end

    test "finds specters with regex patterns", %{registry: registry} do
      pattern = Pattern.new(%{id: "~r/^[0-9]{3}$/"})
      SubscriptionRegistry.register(registry, "specter1", pattern)

      signal = %{id: "123"}
      assert ["specter1"] = SubscriptionRegistry.find_matching_specters(registry, signal)
    end

    test "returns empty list for non-matching signal", %{registry: registry} do
      pattern = Pattern.new(%{type: "test.event"})
      SubscriptionRegistry.register(registry, "specter1", pattern)

      signal = %{type: "other.event"}
      assert [] = SubscriptionRegistry.find_matching_specters(registry, signal)
    end

    test "raises error for unknown registry", %{registry: _registry} do
      signal = %{type: "test.event"}

      assert_raise ArgumentError, ~r/unknown registry/, fn ->
        SubscriptionRegistry.find_matching_specters(:unknown_registry, signal)
      end
    end

    test "finds multiple matching specters", %{registry: registry} do
      pattern1 = Pattern.new(%{type: "test.*"})
      pattern2 = Pattern.new(%{type: "test.event"})

      SubscriptionRegistry.register(registry, "specter1", pattern1)
      SubscriptionRegistry.register(registry, "specter2", pattern2)

      signal = %{type: "test.event"}
      matches = SubscriptionRegistry.find_matching_specters(registry, signal)

      assert length(matches) == 2
      assert "specter1" in matches
      assert "specter2" in matches
    end
  end
end
