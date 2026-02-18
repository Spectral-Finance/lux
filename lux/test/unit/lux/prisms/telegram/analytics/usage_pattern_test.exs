defmodule Lux.Prisms.Telegram.Analytics.UsagePatternTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Prisms.Telegram.Analytics.UsagePattern
  alias Lux.Integrations.Telegram.Analytics

  @agent_ctx %{name: "TestAgent"}

  setup do
    start_supervised!({Analytics, [name: :"test_#{:erlang.unique_integer([:positive])}", cleanup_interval_ms: 0]})
    Analytics.reset()
    :ok
  end

  describe "handler/2 - analyze action" do
    test "returns usage patterns when events exist" do
      Analytics.record_event(:message_sent, %{})
      Analytics.record_event(:message_received, %{})
      Analytics.record_event(:command_executed, %{})

      assert {:ok, patterns} = UsagePattern.handler(%{action: "analyze"}, @agent_ctx)
      assert map_size(patterns.hourly_distribution) > 0
      assert map_size(patterns.daily_distribution) > 0
      assert is_integer(patterns.peak_hour)
      assert is_atom(patterns.peak_day)
    end

    test "returns empty patterns when no events" do
      assert {:ok, patterns} = UsagePattern.handler(%{action: "analyze"}, @agent_ctx)
      assert patterns.hourly_distribution == %{}
      assert patterns.daily_distribution == %{}
    end

    test "peak_hour is valid (0-23)" do
      Analytics.record_event(:message_sent, %{})

      assert {:ok, patterns} = UsagePattern.handler(%{action: "analyze"}, @agent_ctx)
      assert patterns.peak_hour >= 0 and patterns.peak_hour <= 23
    end

    test "peak_day is a valid day atom" do
      Analytics.record_event(:message_sent, %{})

      assert {:ok, patterns} = UsagePattern.handler(%{action: "analyze"}, @agent_ctx)
      valid_days = [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]
      assert patterns.peak_day in valid_days
    end
  end

  describe "handler/2 - error cases" do
    test "returns error for unknown action" do
      assert {:error, "Unknown action: invalid. Use 'analyze'."} =
               UsagePattern.handler(%{action: "invalid"}, @agent_ctx)
    end

    test "returns error for missing action" do
      assert {:error, "Missing required parameter: action"} =
               UsagePattern.handler(%{}, @agent_ctx)
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = UsagePattern.view()
      assert prism.input_schema.required == ["action"]
      assert Map.has_key?(prism.input_schema.properties, :action)
    end

    test "validates output schema" do
      prism = UsagePattern.view()
      assert Map.has_key?(prism.output_schema.properties, :hourly_distribution)
      assert Map.has_key?(prism.output_schema.properties, :daily_distribution)
      assert Map.has_key?(prism.output_schema.properties, :peak_hour)
      assert Map.has_key?(prism.output_schema.properties, :peak_day)
    end
  end
end
