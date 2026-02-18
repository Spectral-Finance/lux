defmodule Lux.Prisms.Telegram.Analytics.ErrorMonitoringTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Prisms.Telegram.Analytics.ErrorMonitoring
  alias Lux.Integrations.Telegram.Analytics

  @agent_ctx %{name: "TestAgent"}

  setup do
    start_supervised!({Analytics, [name: :"test_#{:erlang.unique_integer([:positive])}", cleanup_interval_ms: 0]})
    Analytics.reset()
    :ok
  end

  describe "handler/2 - record action" do
    test "records an API error" do
      assert {:ok, %{recorded: true, error_type: "api_error"}} =
               ErrorMonitoring.handler(
                 %{action: "record", error_type: "api_error", message: "Rate limit exceeded"},
                 @agent_ctx
               )
    end

    test "records a timeout error" do
      assert {:ok, %{recorded: true, error_type: "timeout"}} =
               ErrorMonitoring.handler(
                 %{action: "record", error_type: "timeout"},
                 @agent_ctx
               )
    end

    test "records with full metadata" do
      assert {:ok, %{recorded: true, error_type: "validation"}} =
               ErrorMonitoring.handler(
                 %{
                   action: "record",
                   error_type: "validation",
                   message: "Invalid chat_id",
                   chat_id: 123,
                   user_id: 42,
                   operation: "send_message"
                 },
                 @agent_ctx
               )
    end

    test "returns error when error_type missing" do
      assert {:error, "Missing or invalid error_type parameter"} =
               ErrorMonitoring.handler(%{action: "record"}, @agent_ctx)
    end

    test "returns error when error_type is empty" do
      assert {:error, "Missing or invalid error_type parameter"} =
               ErrorMonitoring.handler(%{action: "record", error_type: ""}, @agent_ctx)
    end
  end

  describe "handler/2 - stats action" do
    test "returns error statistics" do
      ErrorMonitoring.handler(%{action: "record", error_type: "api_error"}, @agent_ctx)
      ErrorMonitoring.handler(%{action: "record", error_type: "timeout"}, @agent_ctx)
      ErrorMonitoring.handler(%{action: "record", error_type: "api_error"}, @agent_ctx)

      assert {:ok, stats} = ErrorMonitoring.handler(%{action: "stats"}, @agent_ctx)
      assert stats.total_errors == 3
      assert stats.errors_by_type["api_error"] == 2
      assert stats.errors_by_type["timeout"] == 1
    end

    test "returns zeroes when no errors recorded" do
      assert {:ok, stats} = ErrorMonitoring.handler(%{action: "stats"}, @agent_ctx)
      assert stats.total_errors == 0
      assert stats.errors_by_type == %{}
    end

    test "returns recent errors" do
      ErrorMonitoring.handler(
        %{action: "record", error_type: "api_error", message: "Bad request"},
        @agent_ctx
      )

      assert {:ok, stats} = ErrorMonitoring.handler(%{action: "stats"}, @agent_ctx)
      assert length(stats.recent_errors) == 1
    end

    test "calculates error rate" do
      # Record some normal events first
      Analytics.record_event(:message_sent, %{})
      Analytics.record_event(:message_sent, %{})

      ErrorMonitoring.handler(%{action: "record", error_type: "timeout"}, @agent_ctx)

      assert {:ok, stats} = ErrorMonitoring.handler(%{action: "stats"}, @agent_ctx)
      assert stats.error_rate > 0
    end
  end

  describe "handler/2 - error cases" do
    test "returns error for unknown action" do
      assert {:error, "Unknown action: bad. Use 'record' or 'stats'."} =
               ErrorMonitoring.handler(%{action: "bad"}, @agent_ctx)
    end

    test "returns error for missing action" do
      assert {:error, "Missing required parameter: action"} =
               ErrorMonitoring.handler(%{}, @agent_ctx)
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = ErrorMonitoring.view()
      assert prism.input_schema.required == ["action"]
      assert Map.has_key?(prism.input_schema.properties, :action)
      assert Map.has_key?(prism.input_schema.properties, :error_type)
      assert Map.has_key?(prism.input_schema.properties, :message)
      assert Map.has_key?(prism.input_schema.properties, :operation)
    end

    test "validates output schema" do
      prism = ErrorMonitoring.view()
      assert Map.has_key?(prism.output_schema.properties, :recorded)
      assert Map.has_key?(prism.output_schema.properties, :total_errors)
      assert Map.has_key?(prism.output_schema.properties, :error_rate)
    end
  end
end
