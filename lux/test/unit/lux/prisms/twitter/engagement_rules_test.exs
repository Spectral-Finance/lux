defmodule Lux.Prisms.Twitter.EngagementRulesTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Twitter.EngagementRules

  setup do
    name = :"engage_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = EngagementRules.start_link(name: name)
    %{pid: pid}
  end

  test "add and list rules", %{pid: pid} do
    {:ok, rule} = EngagementRules.add_rule(pid, %{
      name: "Crypto engagement",
      conditions: [{:keyword, ["bitcoin", "ethereum"]}],
      actions: [:like, :retweet]
    })
    assert rule.name == "Crypto engagement"
    {:ok, rules} = EngagementRules.list_rules(pid)
    assert length(rules) == 1
  end

  test "evaluate matching tweet", %{pid: pid} do
    {:ok, _} = EngagementRules.add_rule(pid, %{
      conditions: [{:keyword, ["elixir"]}],
      actions: [:like]
    })
    {:ok, result} = EngagementRules.evaluate(pid, %{text: "I love Elixir!", id: "123"})
    assert :like in result.actions
    assert length(result.matched_rules) == 1
  end

  test "evaluate non-matching tweet", %{pid: pid} do
    {:ok, _} = EngagementRules.add_rule(pid, %{
      conditions: [{:keyword, ["rust"]}],
      actions: [:like]
    })
    {:ok, result} = EngagementRules.evaluate(pid, %{text: "I love Python!", id: "456"})
    assert result.actions == []
  end

  test "min_followers condition", %{pid: pid} do
    {:ok, _} = EngagementRules.add_rule(pid, %{
      conditions: [{:min_followers, 1000}],
      actions: [:follow]
    })
    {:ok, r1} = EngagementRules.evaluate(pid, %{text: "hi", author_followers: 5000, id: "1"})
    assert :follow in r1.actions
    {:ok, r2} = EngagementRules.evaluate(pid, %{text: "hi", author_followers: 100, id: "2"})
    assert r2.actions == []
  end

  test "remove rule", %{pid: pid} do
    {:ok, rule} = EngagementRules.add_rule(pid, %{actions: [:like]})
    :ok = EngagementRules.remove_rule(pid, rule.id)
    {:ok, rules} = EngagementRules.list_rules(pid)
    assert rules == []
  end

  test "rate limiting", %{pid: pid} do
    EngagementRules.set_rate_limit(pid, :like, 2)
    {:ok, _} = EngagementRules.add_rule(pid, %{conditions: [], actions: [:like]})

    {:ok, _} = EngagementRules.evaluate(pid, %{text: "1", id: "1"})
    {:ok, _} = EngagementRules.evaluate(pid, %{text: "2", id: "2"})
    {:ok, r3} = EngagementRules.evaluate(pid, %{text: "3", id: "3"})
    assert :like not in r3.actions
  end

  test "multiple conditions (AND logic)", %{pid: pid} do
    {:ok, _} = EngagementRules.add_rule(pid, %{
      conditions: [{:keyword, ["ai"]}, {:min_likes, 10}],
      actions: [:retweet]
    })
    {:ok, r1} = EngagementRules.evaluate(pid, %{text: "AI is great", like_count: 50, id: "1"})
    assert :retweet in r1.actions
    {:ok, r2} = EngagementRules.evaluate(pid, %{text: "AI is great", like_count: 2, id: "2"})
    assert r2.actions == []
  end

  test "action counts tracking", %{pid: pid} do
    {:ok, _} = EngagementRules.add_rule(pid, %{conditions: [], actions: [:like, :retweet]})
    {:ok, _} = EngagementRules.evaluate(pid, %{text: "test", id: "1"})
    {:ok, counts} = EngagementRules.get_action_counts(pid)
    assert counts[:like] == 1
    assert counts[:retweet] == 1
  end
end
