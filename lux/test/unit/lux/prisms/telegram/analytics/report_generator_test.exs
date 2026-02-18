defmodule Lux.Prisms.Telegram.Analytics.ReportGeneratorTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Prisms.Telegram.Analytics.ReportGenerator
  alias Lux.Integrations.Telegram.Analytics

  @agent_ctx %{name: "TestAgent"}

  setup do
    start_supervised!({Analytics, [name: :"test_#{:erlang.unique_integer([:positive])}", cleanup_interval_ms: 0]})
    Analytics.reset()
    :ok
  end

  describe "handler/2 - full_report action" do
    test "generates a complete report" do
      Analytics.record_message(:sent, %{user_id: 42})
      Analytics.record_command(:start, %{})
      Analytics.record_error(:timeout, %{})

      assert {:ok, %{report: report}} = ReportGenerator.handler(%{action: "full_report"}, @agent_ctx)
      assert is_binary(report)
      assert String.contains?(report, "📊 TELEGRAM BOT ANALYTICS REPORT")
      assert String.contains?(report, "📨 MESSAGE STATISTICS")
      assert String.contains?(report, "🤖 COMMAND STATISTICS")
      assert String.contains?(report, "👥 USER ENGAGEMENT")
      assert String.contains?(report, "❌ ERROR MONITORING")
      assert String.contains?(report, "⚡ PERFORMANCE METRICS")
      assert String.contains?(report, "📈 USAGE PATTERNS")
    end

    test "generates report with no data" do
      assert {:ok, %{report: report}} = ReportGenerator.handler(%{action: "full_report"}, @agent_ctx)
      assert is_binary(report)
      assert String.contains?(report, "📊 TELEGRAM BOT ANALYTICS REPORT")
    end
  end

  describe "handler/2 - section_report action" do
    test "generates messages section report" do
      Analytics.record_message(:sent, %{})
      Analytics.record_message(:received, %{})

      assert {:ok, %{report: report}} =
               ReportGenerator.handler(%{action: "section_report", section: "messages"}, @agent_ctx)

      assert is_binary(report)
      assert String.contains?(report, "Message")
    end

    test "generates commands section report" do
      Analytics.record_command(:start, %{})

      assert {:ok, %{report: report}} =
               ReportGenerator.handler(%{action: "section_report", section: "commands"}, @agent_ctx)

      assert is_binary(report)
      assert String.contains?(report, "Command")
    end

    test "generates engagement section report" do
      Analytics.track_user_activity(42)

      assert {:ok, %{report: report}} =
               ReportGenerator.handler(%{action: "section_report", section: "engagement"}, @agent_ctx)

      assert is_binary(report)
      assert String.contains?(report, "Engagement")
    end

    test "generates errors section report" do
      Analytics.record_error(:timeout, %{})

      assert {:ok, %{report: report}} =
               ReportGenerator.handler(%{action: "section_report", section: "errors"}, @agent_ctx)

      assert is_binary(report)
      assert String.contains?(report, "Error")
    end

    test "generates performance section report" do
      Analytics.record_response_time(:send_message, 150)

      assert {:ok, %{report: report}} =
               ReportGenerator.handler(%{action: "section_report", section: "performance"}, @agent_ctx)

      assert is_binary(report)
      assert String.contains?(report, "Performance")
    end

    test "generates usage_patterns section report" do
      Analytics.record_event(:message_sent, %{})

      assert {:ok, %{report: report}} =
               ReportGenerator.handler(%{action: "section_report", section: "usage_patterns"}, @agent_ctx)

      assert is_binary(report)
      assert String.contains?(report, "Usage")
    end

    test "returns error when section missing" do
      assert {:error, "Missing or invalid section parameter"} =
               ReportGenerator.handler(%{action: "section_report"}, @agent_ctx)
    end

    test "handles unknown section gracefully" do
      assert {:ok, %{report: report}} =
               ReportGenerator.handler(%{action: "section_report", section: "unknown"}, @agent_ctx)

      assert String.contains?(report, "Unknown section")
    end
  end

  describe "handler/2 - error cases" do
    test "returns error for unknown action" do
      assert {:error, "Unknown action: bad. Use 'full_report' or 'section_report'."} =
               ReportGenerator.handler(%{action: "bad"}, @agent_ctx)
    end

    test "returns error for missing action" do
      assert {:error, "Missing required parameter: action"} =
               ReportGenerator.handler(%{}, @agent_ctx)
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = ReportGenerator.view()
      assert prism.input_schema.required == ["action"]
      assert Map.has_key?(prism.input_schema.properties, :action)
      assert Map.has_key?(prism.input_schema.properties, :section)
    end

    test "validates output schema" do
      prism = ReportGenerator.view()
      assert Map.has_key?(prism.output_schema.properties, :report)
    end
  end
end
