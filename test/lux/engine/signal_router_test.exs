defmodule Lux.Engine.SignalRouterTest do
  use ExUnit.Case

  alias Lux.Signal
  alias Lux.Engine.Subscription.Pattern
  alias Lux.Engine.SignalRouter
  alias Lux.Engine.SubscriptionRegistry

  setup do
    registry_name = :"test_registry_#{System.unique_integer()}"
    start_supervised!({Registry, keys: :unique, name: registry_name})
    start_supervised!({SubscriptionRegistry, name: registry_name})
    start_supervised!({SignalRouter, name: registry_name})
    %{registry_name: registry_name}
  end

  test "route_signal/2 routes signal to matching specters", %{registry_name: registry_name} do
    pattern = Pattern.new(%{schema_id: "test.event", sender: "test", recipient: "specter1"})
    :ok = SignalRouter.register(registry_name, "specter1", pattern)

    signal = %Signal{
      schema_id: "test.event",
      sender: "test",
      recipient: "specter1",
      payload: %{extra: "field"}
    }

    matches = SignalRouter.route_signal(registry_name, signal)
    assert length(matches) > 0
    assert "specter1" in matches
  end

  test "register/3 registers new pattern for specter", %{registry_name: registry_name} do
    pattern = Pattern.new(%{schema_id: "test.event", sender: "test", recipient: "specter1"})
    :ok = SignalRouter.register(registry_name, "specter1", pattern)

    signal = %Signal{
      schema_id: "test.event",
      sender: "test",
      recipient: "specter1",
      payload: %{}
    }

    matches = SignalRouter.route_signal(registry_name, signal)
    assert length(matches) > 0
    assert "specter1" in matches
  end

  test "register/3 updates existing pattern for specter", %{registry_name: registry_name} do
    pattern1 = Pattern.new(%{schema_id: "test.event.1", sender: "test", recipient: "specter1"})
    pattern2 = Pattern.new(%{schema_id: "test.event.2", sender: "test", recipient: "specter1"})

    :ok = SignalRouter.register(registry_name, "specter1", pattern1)
    :ok = SignalRouter.register(registry_name, "specter1", pattern2)

    signal = %Signal{
      schema_id: "test.event.2",
      sender: "test",
      recipient: "specter1",
      payload: %{}
    }

    matches = SignalRouter.route_signal(registry_name, signal)
    assert length(matches) > 0
    assert "specter1" in matches
  end
end
