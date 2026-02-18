defmodule Lux.Prisms.Telegram.Analytics.CustomMetricTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Prisms.Telegram.Analytics.CustomMetric
  alias Lux.Integrations.Telegram.Analytics

  @agent_ctx %{name: "TestAgent"}

  setup do
    start_supervised!({Analytics, [name: :"test_#{:erlang.unique_integer([:positive])}", cleanup_interval_ms: 0]})
    Analytics.reset()
    :ok
  end

  describe "handler/2 - define action" do
    test "defines a counter metric" do
      assert {:ok, %{defined: true, name: "page_views", type: "counter"}} =
               CustomMetric.handler(
                 %{action: "define", name: "page_views", type: "counter", description: "Total page views"},
                 @agent_ctx
               )
    end

    test "defines a gauge metric" do
      assert {:ok, %{defined: true, name: "cpu_usage", type: "gauge"}} =
               CustomMetric.handler(
                 %{action: "define", name: "cpu_usage", type: "gauge"},
                 @agent_ctx
               )
    end

    test "defines a histogram metric" do
      assert {:ok, %{defined: true, name: "latency", type: "histogram"}} =
               CustomMetric.handler(
                 %{action: "define", name: "latency", type: "histogram"},
                 @agent_ctx
               )
    end

    test "returns error when name missing" do
      assert {:error, "Missing or invalid name"} =
               CustomMetric.handler(%{action: "define", type: "counter"}, @agent_ctx)
    end

    test "returns error when type missing" do
      assert {:error, "Missing or invalid type. Must be 'counter', 'gauge', or 'histogram'."} =
               CustomMetric.handler(%{action: "define", name: "test"}, @agent_ctx)
    end

    test "returns error for invalid type" do
      assert {:error, "Missing or invalid type. Must be 'counter', 'gauge', or 'histogram'."} =
               CustomMetric.handler(%{action: "define", name: "test", type: "invalid"}, @agent_ctx)
    end
  end

  describe "handler/2 - record action" do
    test "records a metric value" do
      CustomMetric.handler(
        %{action: "define", name: "score", type: "gauge"},
        @agent_ctx
      )

      assert {:ok, %{recorded: true, name: "score", value: 4.5}} =
               CustomMetric.handler(
                 %{action: "record", name: "score", value: 4.5},
                 @agent_ctx
               )
    end

    test "records integer values" do
      CustomMetric.handler(
        %{action: "define", name: "count", type: "counter"},
        @agent_ctx
      )

      assert {:ok, %{recorded: true, name: "count", value: 10}} =
               CustomMetric.handler(
                 %{action: "record", name: "count", value: 10},
                 @agent_ctx
               )
    end

    test "returns error when name missing" do
      assert {:error, "Missing or invalid name"} =
               CustomMetric.handler(%{action: "record", value: 5}, @agent_ctx)
    end

    test "returns error when value missing" do
      assert {:error, "Missing or invalid value (must be a number)"} =
               CustomMetric.handler(%{action: "record", name: "test"}, @agent_ctx)
    end

    test "returns error when value is not a number" do
      assert {:error, "Missing or invalid value (must be a number)"} =
               CustomMetric.handler(%{action: "record", name: "test", value: "abc"}, @agent_ctx)
    end
  end

  describe "handler/2 - get action" do
    test "retrieves a custom metric value" do
      CustomMetric.handler(%{action: "define", name: "score", type: "gauge"}, @agent_ctx)
      CustomMetric.handler(%{action: "record", name: "score", value: 8.5}, @agent_ctx)

      assert {:ok, %{name: "score", value: 8.5}} =
               CustomMetric.handler(%{action: "get", name: "score"}, @agent_ctx)
    end

    test "retrieves a counter metric value" do
      CustomMetric.handler(%{action: "define", name: "clicks", type: "counter"}, @agent_ctx)
      CustomMetric.handler(%{action: "record", name: "clicks", value: 3}, @agent_ctx)
      CustomMetric.handler(%{action: "record", name: "clicks", value: 7}, @agent_ctx)

      assert {:ok, %{name: "clicks", value: 10}} =
               CustomMetric.handler(%{action: "get", name: "clicks"}, @agent_ctx)
    end

    test "returns error for undefined metric" do
      assert {:error, "Custom metric 'nonexistent' not found"} =
               CustomMetric.handler(%{action: "get", name: "nonexistent"}, @agent_ctx)
    end

    test "returns error when name missing" do
      assert {:error, "Missing or invalid name"} =
               CustomMetric.handler(%{action: "get"}, @agent_ctx)
    end
  end

  describe "handler/2 - list action" do
    test "lists all custom metrics" do
      CustomMetric.handler(%{action: "define", name: "metric_a", type: "counter"}, @agent_ctx)
      CustomMetric.handler(%{action: "define", name: "metric_b", type: "gauge"}, @agent_ctx)

      assert {:ok, %{metrics: metrics}} =
               CustomMetric.handler(%{action: "list"}, @agent_ctx)

      assert length(metrics) == 2
    end

    test "returns empty list when no metrics defined" do
      assert {:ok, %{metrics: []}} =
               CustomMetric.handler(%{action: "list"}, @agent_ctx)
    end
  end

  describe "handler/2 - error cases" do
    test "returns error for unknown action" do
      assert {:error, "Unknown action: bad. Use 'define', 'record', 'get', or 'list'."} =
               CustomMetric.handler(%{action: "bad"}, @agent_ctx)
    end

    test "returns error for missing action" do
      assert {:error, "Missing required parameter: action"} =
               CustomMetric.handler(%{}, @agent_ctx)
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = CustomMetric.view()
      assert prism.input_schema.required == ["action"]
      assert Map.has_key?(prism.input_schema.properties, :action)
      assert Map.has_key?(prism.input_schema.properties, :name)
      assert Map.has_key?(prism.input_schema.properties, :type)
      assert Map.has_key?(prism.input_schema.properties, :value)
    end

    test "validates output schema" do
      prism = CustomMetric.view()
      assert Map.has_key?(prism.output_schema.properties, :defined)
      assert Map.has_key?(prism.output_schema.properties, :recorded)
      assert Map.has_key?(prism.output_schema.properties, :metrics)
    end
  end
end
