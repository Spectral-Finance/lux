defmodule Lux.Engine.SubscriptionTest do
  use ExUnit.Case, async: true

  alias Lux.Engine.Subscription

  describe "new/2" do
    test "creates a new subscription with valid pattern and specter_id" do
      pattern = %{type: "test.event", priority: "high"}
      specter_id = "specter123"

      subscription = Subscription.new(pattern, specter_id)

      assert subscription.pattern == pattern
      assert subscription.specter_id == specter_id
      assert is_binary(subscription.id)
    end

    test "raises when pattern is not a map" do
      assert_raise FunctionClauseError, fn ->
        Subscription.new("not a map", "specter123")
      end
    end

    test "raises when specter_id is not a binary" do
      assert_raise FunctionClauseError, fn ->
        Subscription.new(%{type: "test"}, 123)
      end
    end
  end

  describe "to_ets_record/1" do
    test "converts subscription to ETS record format" do
      pattern = %{type: "test.event"}
      specter_id = "specter123"
      subscription = Subscription.new(pattern, specter_id)

      {key, value} = Subscription.to_ets_record(subscription)

      assert key == {pattern, subscription.id}
      assert value == {[], specter_id}
    end
  end
end
