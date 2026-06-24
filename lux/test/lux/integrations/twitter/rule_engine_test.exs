defmodule Lux.Integrations.Twitter.RuleEngineTest do
  use ExUnit.Case
  alias Lux.Integrations.Twitter.RuleEngine

  test "evaluates help tweets" do
    assert RuleEngine.evaluate("Can someone help me with this?") == {:reply, "How can we assist you?"}
  end

  test "evaluates awesome tweets" do
    assert RuleEngine.evaluate("This product is awesome!") == :like
  end

  test "ignores long tweets" do
    long_tweet = String.duplicate("a", 201)
    assert RuleEngine.evaluate(long_tweet) == :ignore
  end

  test "ignores other tweets" do
    assert RuleEngine.evaluate("Just a normal day") == :ignore
  end
end
