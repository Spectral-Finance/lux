defmodule Lux.Engine.SignalRouterTest do
  use ExUnit.Case, async: true

  alias Lux.Engine.SignalRouter
  alias Lux.Engine.Subscription.Pattern

  setup do
    test_id = :erlang.unique_integer()
    registry_name = :"test_registry_#{test_id}"
    router_registry_name = :"test_router_#{test_id}"

    start_supervised!({Registry, keys: :unique, name: registry_name})
    start_supervised!({Registry, keys: :unique, name: router_registry_name})
    start_supervised!({Lux.Engine.SubscriptionRegistry, name: registry_name})
    start_supervised!({SignalRouter, name: registry_name})

    %{registry_name: registry_name}
  end

  describe "route_signal/2" do
    test "routes signal to matching specters", %{registry_name: registry_name} do
      pattern1 = %Pattern{pattern: %{type: "test.event"}}
      pattern2 = %Pattern{pattern: %{type: "test.event", priority: "high"}}

      :ok = SignalRouter.register(registry_name, "specter1", pattern1)
      :ok = SignalRouter.register(registry_name, "specter2", pattern2)

      signal = %{type: "test.event", priority: "high", extra: "field"}
      matches = SignalRouter.route_signal(registry_name, signal)

      assert length(matches) == 2
      assert "specter1" in matches
      assert "specter2" in matches
    end

    test "returns empty list for non-matching signal", %{registry_name: registry_name} do
      pattern = %Pattern{pattern: %{type: "test.event"}}
      :ok = SignalRouter.register(registry_name, "specter1", pattern)

      signal = %{type: "other.event"}
      matches = SignalRouter.route_signal(registry_name, signal)

      assert matches == []
    end

    test "handles signals with extra fields", %{registry_name: registry_name} do
      pattern = %Pattern{pattern: %{type: "test.event"}}
      :ok = SignalRouter.register(registry_name, "specter1", pattern)

      signal = %{type: "test.event", extra: "field"}
      matches = SignalRouter.route_signal(registry_name, signal)

      assert length(matches) == 1
      assert "specter1" in matches
    end
  end

  describe "register/3" do
    test "registers new pattern for specter", %{registry_name: registry_name} do
      pattern = %Pattern{pattern: %{type: "test.event"}}
      assert :ok = SignalRouter.register(registry_name, "specter1", pattern)
    end

    test "updates existing pattern for specter", %{registry_name: registry_name} do
      pattern1 = %Pattern{pattern: %{type: "test.event1"}}
      pattern2 = %Pattern{pattern: %{type: "test.event2"}}

      :ok = SignalRouter.register(registry_name, "specter1", pattern1)
      :ok = SignalRouter.register(registry_name, "specter1", pattern2)

      signal1 = %{type: "test.event1"}
      signal2 = %{type: "test.event2"}

      assert SignalRouter.route_signal(registry_name, signal1) == []
      matches = SignalRouter.route_signal(registry_name, signal2)
      assert length(matches) == 1
      assert "specter1" in matches
    end
  end

  describe "unregister/2" do
    test "removes all patterns for specter", %{registry_name: registry_name} do
      pattern = %Pattern{pattern: %{type: "test.event"}}
      :ok = SignalRouter.register(registry_name, "specter1", pattern)

      :ok = SignalRouter.unregister(registry_name, "specter1")

      signal = %{type: "test.event"}
      assert SignalRouter.route_signal(registry_name, signal) == []
    end

    test "returns ok for non-existent specter", %{registry_name: registry_name} do
      assert :ok = SignalRouter.unregister(registry_name, "nonexistent")
    end
  end

  describe "performance" do
    test "efficiently routes signals with many subscriptions", %{registry_name: registry_name} do
      for i <- 1..5 do
        pattern = %Pattern{
          pattern: %{
            type: "test.event",
            category: "cat#{rem(i, 10)}",
            priority: if(rem(i, 2) == 0, do: "high", else: "low")
          }
        }

        :ok = SignalRouter.register(registry_name, "specter#{i}", pattern)
      end

      signal = %{type: "test.event", category: "cat1", priority: "high"}
      matches = SignalRouter.route_signal(registry_name, signal)

      assert length(matches) > 0
      assert Enum.all?(matches, &String.starts_with?(&1, "specter"))
    end

    test "handles concurrent registrations and routing", %{registry_name: registry_name} do
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            pattern = %Pattern{pattern: %{type: "test.event.#{i}", index: 1}}
            :ok = SignalRouter.register(registry_name, "specter_#{i}_1", pattern)
          end)
        end

      routing_tasks =
        for i <- 1..10 do
          Task.async(fn ->
            signal = %{type: "test.event.#{i}", index: 2}
            SignalRouter.route_signal(registry_name, signal)
          end)
        end

      Task.await_many(tasks ++ routing_tasks, 5000)
    end
  end
end
