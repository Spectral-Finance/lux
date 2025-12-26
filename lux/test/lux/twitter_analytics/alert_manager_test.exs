defmodule Lux.TwitterAnalytics.AlertManagerTest do
  use ExUnit.Case, async: false

  alias Lux.TwitterAnalytics.{AlertManager, Aggregator, Storage}

  setup do
    {:ok, _agg_pid} = start_supervised(Aggregator)
    {:ok, _alert_pid} = start_supervised(AlertManager)
    Storage.clear_all()

    on_exit(fn ->
      Storage.clear_all()
    end)

    :ok
  end

  describe "add_rule/1" do
    test "adds a valid rule" do
      rule = %{
        metric: :likes,
        threshold: 100,
        comparator: :greater_than
      }

      assert {:ok, rule_id} = AlertManager.add_rule(rule)
      assert is_binary(rule_id)
    end

    test "auto-generates rule ID if not provided" do
      rule = %{
        metric: :retweets,
        threshold: 50,
        comparator: :less_than
      }

      assert {:ok, rule_id} = AlertManager.add_rule(rule)
      {:ok, rules} = AlertManager.list_rules()
      assert Enum.any?(rules, &(&1.id == rule_id))
    end

    test "rejects invalid rule" do
      invalid_rule = %{threshold: 100}
      assert {:error, :invalid_rule} = AlertManager.add_rule(invalid_rule)
    end

    test "accepts rule with callback" do
      callback = fn _alert, _metric -> :ok end

      rule = %{
        metric: :likes,
        threshold: 100,
        comparator: :greater_than,
        action: callback
      }

      assert {:ok, _rule_id} = AlertManager.add_rule(rule)
    end
  end

  describe "remove_rule/1" do
    test "removes an existing rule" do
      rule = %{metric: :likes, threshold: 100, comparator: :greater_than}
      {:ok, rule_id} = AlertManager.add_rule(rule)

      assert :ok = AlertManager.remove_rule(rule_id)

      {:ok, rules} = AlertManager.list_rules()
      refute Enum.any?(rules, &(&1.id == rule_id))
    end
  end

  describe "list_rules/0" do
    test "lists all active rules" do
      rule1 = %{metric: :likes, threshold: 100, comparator: :greater_than}
      rule2 = %{metric: :retweets, threshold: 50, comparator: :less_than}

      {:ok, id1} = AlertManager.add_rule(rule1)
      {:ok, id2} = AlertManager.add_rule(rule2)

      {:ok, rules} = AlertManager.list_rules()
      assert length(rules) == 2
      assert Enum.any?(rules, &(&1.id == id1))
      assert Enum.any?(rules, &(&1.id == id2))
    end

    test "returns empty list when no rules" do
      {:ok, rules} = AlertManager.list_rules()
      assert rules == []
    end
  end

  describe "list_alerts/1" do
    test "lists recent alerts" do
      # Create some test alerts
      Storage.store_alert(%{
        id: "alert1",
        rule_id: "rule1",
        triggered_at: DateTime.utc_now(),
        metric_type: :likes,
        threshold: 100,
        actual_value: 150,
        tweet_id: "tweet123"
      })

      {:ok, alerts} = AlertManager.list_alerts()
      assert length(alerts) >= 1
    end

    test "filters alerts by time" do
      now = DateTime.utc_now()
      old_time = DateTime.add(now, -2, :hour)

      Storage.store_alert(%{
        id: "alert1",
        rule_id: "rule1",
        triggered_at: old_time,
        metric_type: :likes,
        threshold: 100,
        actual_value: 150,
        tweet_id: "tweet123"
      })

      {:ok, alerts} = AlertManager.list_alerts(since: DateTime.add(now, -1, :hour))
      assert alerts == []
    end
  end

  describe "comparators" do
    test "validates all comparator types" do
      comparators = [:greater_than, :less_than, :equal, :greater_or_equal, :less_or_equal]

      Enum.each(comparators, fn comp ->
        rule = %{metric: :likes, threshold: 100, comparator: comp}
        assert {:ok, _} = AlertManager.add_rule(rule)
      end)
    end
  end

  describe "metric types" do
    test "supports all metric types" do
      metrics = [:likes, :retweets, :replies, :quotes, :engagement, :sentiment]

      Enum.each(metrics, fn metric ->
        rule = %{metric: metric, threshold: 100, comparator: :greater_than}
        assert {:ok, _} = AlertManager.add_rule(rule)
      end)
    end
  end
end
