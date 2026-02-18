defmodule Lux.Prisms.Telegram.Analytics.PerformanceMetricsTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Prisms.Telegram.Analytics.PerformanceMetrics
  alias Lux.Integrations.Telegram.Analytics

  @agent_ctx %{name: "TestAgent"}

  setup do
    start_supervised!({Analytics, [name: :"test_#{:erlang.unique_integer([:positive])}", cleanup_interval_ms: 0]})
    Analytics.reset()
    :ok
  end

  describe "handler/2 - record action" do
    test "records a response time measurement" do
      assert {:ok, %{recorded: true, operation: "send_message", response_time_ms: 150}} =
               PerformanceMetrics.handler(
                 %{action: "record", operation: "send_message", response_time_ms: 150},
                 @agent_ctx
               )
    end

    test "records zero response time" do
      assert {:ok, %{recorded: true, response_time_ms: 0}} =
               PerformanceMetrics.handler(
                 %{action: "record", operation: "cache_hit", response_time_ms: 0},
                 @agent_ctx
               )
    end

    test "records float response times" do
      assert {:ok, %{recorded: true, response_time_ms: 42.5}} =
               PerformanceMetrics.handler(
                 %{action: "record", operation: "fast_op", response_time_ms: 42.5},
                 @agent_ctx
               )
    end

    test "returns error when operation missing" do
      assert {:error, "Missing or invalid operation"} =
               PerformanceMetrics.handler(
                 %{action: "record", response_time_ms: 150},
                 @agent_ctx
               )
    end

    test "returns error when response_time_ms missing" do
      assert {:error, "Missing or invalid response_time_ms (must be a non-negative number)"} =
               PerformanceMetrics.handler(
                 %{action: "record", operation: "test"},
                 @agent_ctx
               )
    end

    test "returns error for negative response time" do
      assert {:error, "Missing or invalid response_time_ms (must be a non-negative number)"} =
               PerformanceMetrics.handler(
                 %{action: "record", operation: "test", response_time_ms: -1},
                 @agent_ctx
               )
    end
  end

  describe "handler/2 - stats action" do
    test "returns performance statistics" do
      PerformanceMetrics.handler(
        %{action: "record", operation: "op1", response_time_ms: 100},
        @agent_ctx
      )

      PerformanceMetrics.handler(
        %{action: "record", operation: "op2", response_time_ms: 200},
        @agent_ctx
      )

      assert {:ok, stats} = PerformanceMetrics.handler(%{action: "stats"}, @agent_ctx)
      assert is_float(stats.avg_response_time_ms)
      assert is_float(stats.p50_response_time_ms)
      assert is_float(stats.p95_response_time_ms)
      assert is_float(stats.p99_response_time_ms)
      assert is_float(stats.min_response_time_ms)
      assert is_float(stats.max_response_time_ms)
    end

    test "returns zeroes when no metrics recorded" do
      assert {:ok, stats} = PerformanceMetrics.handler(%{action: "stats"}, @agent_ctx)
      assert stats.avg_response_time_ms == 0.0
      assert stats.p50_response_time_ms == 0.0
    end
  end

  describe "handler/2 - error cases" do
    test "returns error for unknown action" do
      assert {:error, "Unknown action: bad. Use 'record' or 'stats'."} =
               PerformanceMetrics.handler(%{action: "bad"}, @agent_ctx)
    end

    test "returns error for missing action" do
      assert {:error, "Missing required parameter: action"} =
               PerformanceMetrics.handler(%{}, @agent_ctx)
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = PerformanceMetrics.view()
      assert prism.input_schema.required == ["action"]
      assert Map.has_key?(prism.input_schema.properties, :action)
      assert Map.has_key?(prism.input_schema.properties, :operation)
      assert Map.has_key?(prism.input_schema.properties, :response_time_ms)
    end

    test "validates output schema" do
      prism = PerformanceMetrics.view()
      assert Map.has_key?(prism.output_schema.properties, :recorded)
      assert Map.has_key?(prism.output_schema.properties, :avg_response_time_ms)
      assert Map.has_key?(prism.output_schema.properties, :p95_response_time_ms)
    end
  end
end
