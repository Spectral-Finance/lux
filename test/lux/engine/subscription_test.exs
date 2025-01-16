defmodule Lux.Engine.SubscriptionTest do
  use ExUnit.Case, async: true
  alias Lux.Engine.Subscription

  describe "new/2" do
    test "creates a subscription with valid pattern and specter_id" do
      pattern = %{type: "test.event", priority: "high"}
      specter_id = "test_specter"

      subscription = Subscription.new(pattern, specter_id)

      assert subscription.pattern == pattern
      assert subscription.specter_id == specter_id
      assert is_binary(subscription.id)
    end

    test "raises for invalid inputs" do
      assert_raise FunctionClauseError, fn ->
        Subscription.new("not a map", "specter1")
      end

      assert_raise FunctionClauseError, fn ->
        Subscription.new(%{type: "test"}, nil)
      end
    end
  end

  describe "to_ets_record/1" do
    test "converts subscription to ETS record format" do
      subscription = Subscription.new(%{type: "test.event"}, "specter1")
      {key, value} = Subscription.to_ets_record(subscription)

      {pattern, id} = key
      assert pattern == %{type: "test.event"}
      assert id == subscription.id

      assert value == {[], "specter1"}
    end
  end
end
