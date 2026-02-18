defmodule Lux.Prisms.Telegram.Analytics.MetricAggregationTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Prisms.Telegram.Analytics.MetricAggregation
  alias Lux.Integrations.Telegram.Analytics

  @agent_ctx %{name: "TestAgent"}

  setup do
    start_supervised!({Analytics, [name: :"test_#{:erlang.unique_integer([:positive])}", cleanup_interval_ms: 0]})
    Analytics.reset()
    :ok
  end

  describe "handler/2 - dashboard action" do
    test "returns a complete dashboard" do
      Analytics.record_message(:sent, %{user_id: 42})
      Analytics.record_command(:start, %{})
      Analytics.record_error(:timeout, %{})

      assert {:ok, dashboard} = MetricAggregation.handler(%{action: "dashboard"}, @agent_ctx)
      assert Map.has_key?(dashboard, :messages)
      assert Map.has_key?(dashboard, :commands)
      assert Map.has_key?(dashboard, :engagement)
      assert Map.has_key?(dashboard, :errors)
      assert Map.has_key?(dashboard, :performance)
      assert Map.has_key?(dashboard, :usage_patterns)
      assert Map.has_key?(dashboard, :generated_at)
    end

    test "returns dashboard with zeroes when no data" do
      assert {:ok, dashboard} = MetricAggregation.handler(%{action: "dashboard"}, @agent_ctx)
      assert dashboard.messages.total == 0
      assert dashboard.commands.total_commands == 0
    end
  end

  describe "handler/2 - export action" do
    test "exports all analytics data" do
      Analytics.record_message(:sent, %{chat_id: 123})

      assert {:ok, export} = MetricAggregation.handler(%{action: "export"}, @agent_ctx)
      assert Map.has_key?(export, :events)
      assert Map.has_key?(export, :counters)
      assert Map.has_key?(export, :gauges)
      assert Map.has_key?(export, :custom)
      assert Map.has_key?(export, :exported_at)
    end

    test "exports empty data when nothing recorded" do
      assert {:ok, export} = MetricAggregation.handler(%{action: "export"}, @agent_ctx)
      assert export.events == []
    end
  end

  describe "handler/2 - reset action" do
    test "resets all analytics data" do
      Analytics.record_message(:sent, %{})
      Analytics.record_command(:start, %{})
      Analytics.record_error(:api_error, %{})

      assert {:ok, %{reset: true}} = MetricAggregation.handler(%{action: "reset"}, @agent_ctx)

      stats = Analytics.get_message_stats()
      assert stats.total == 0
    end
  end

  describe "handler/2 - error cases" do
    test "returns error for unknown action" do
      assert {:error, "Unknown action: bad. Use 'dashboard', 'export', or 'reset'."} =
               MetricAggregation.handler(%{action: "bad"}, @agent_ctx)
    end

    test "returns error for missing action" do
      assert {:error, "Missing required parameter: action"} =
               MetricAggregation.handler(%{}, @agent_ctx)
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = MetricAggregation.view()
      assert prism.input_schema.required == ["action"]
      assert Map.has_key?(prism.input_schema.properties, :action)
    end

    test "validates output schema" do
      prism = MetricAggregation.view()
      assert Map.has_key?(prism.output_schema.properties, :messages)
      assert Map.has_key?(prism.output_schema.properties, :commands)
      assert Map.has_key?(prism.output_schema.properties, :reset)
    end
  end
end
