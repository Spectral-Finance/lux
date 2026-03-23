defmodule Lux.Integrations.Telegram.Analytics.FormatterTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias Lux.Integrations.Telegram.Analytics.Formatter

  defp sample_stats do
    now = DateTime.utc_now()

    %{
      messages: [
        %{type: :text, chat_id: 1, timestamp: now},
        %{type: :text, chat_id: 2, timestamp: now},
        %{type: :photo, chat_id: 1, timestamp: now}
      ],
      commands: [
        %{name: "/start", user_id: 1, timestamp: now},
        %{name: "/help", user_id: 2, timestamp: now}
      ],
      errors: [
        %{type: :timeout, endpoint: "/sendMessage", timestamp: now}
      ],
      response_times: [
        %{endpoint: "/sendMessage", duration_ms: 100, timestamp: now},
        %{endpoint: "/sendMessage", duration_ms: 200, timestamp: now},
        %{endpoint: "/getUpdates", duration_ms: 50, timestamp: now}
      ],
      custom_metrics: [
        %{metric_name: "cpu_usage", metric_value: 45.5, tags: %{}, timestamp: now, metric_id: "abc123"}
      ]
    }
  end

  defp empty_stats do
    %{
      messages: [],
      commands: [],
      errors: [],
      response_times: [],
      custom_metrics: []
    }
  end

  describe "to_summary/1" do
    test "produces a structured summary with correct totals" do
      summary = Formatter.to_summary(sample_stats())

      assert summary.messages.total == 3
      assert summary.commands.total == 2
      assert summary.errors.total == 1
      assert is_binary(summary.generated_at)
    end

    test "breaks down messages by type" do
      summary = Formatter.to_summary(sample_stats())

      assert summary.messages.by_type[:text] == 2
      assert summary.messages.by_type[:photo] == 1
    end

    test "computes performance percentiles" do
      summary = Formatter.to_summary(sample_stats())

      assert summary.performance.min == 50
      assert summary.performance.max == 200
      assert is_number(summary.performance.p50)
      assert is_number(summary.performance.p95)
      assert is_number(summary.performance.p99)
      assert is_float(summary.performance.avg_response_time)
    end

    test "includes custom metrics summary" do
      summary = Formatter.to_summary(sample_stats())

      assert Map.has_key?(summary.custom_metrics, "cpu_usage")
      cpu = summary.custom_metrics["cpu_usage"]
      assert cpu.count == 1
      assert cpu.avg == 45.5
    end

    test "handles empty stats" do
      summary = Formatter.to_summary(empty_stats())

      assert summary.messages.total == 0
      assert summary.commands.total == 0
      assert summary.errors.total == 0
      assert summary.performance.avg_response_time == 0.0
      assert summary.performance.min == 0
      assert summary.performance.max == 0
    end
  end

  describe "to_ascii_table/1" do
    test "produces a formatted string" do
      table = Formatter.to_ascii_table(sample_stats())

      assert is_binary(table)
      assert String.contains?(table, "Telegram Bot Analytics Report")
      assert String.contains?(table, "Messages")
      assert String.contains?(table, "Commands")
      assert String.contains?(table, "Errors")
      assert String.contains?(table, "Performance")
    end

    test "includes totals in table" do
      table = Formatter.to_ascii_table(sample_stats())

      assert String.contains?(table, "Total")
      assert String.contains?(table, "3")
    end

    test "includes generated_at timestamp" do
      table = Formatter.to_ascii_table(sample_stats())

      assert String.contains?(table, "Generated at:")
    end

    test "handles empty stats" do
      table = Formatter.to_ascii_table(empty_stats())

      assert is_binary(table)
      assert String.contains?(table, "Telegram Bot Analytics Report")
    end
  end

  describe "to_json/1" do
    test "produces a JSON-serializable map with string keys" do
      json = Formatter.to_json(sample_stats())

      assert is_map(json)
      assert Map.has_key?(json, "messages")
      assert Map.has_key?(json, "commands")
      assert Map.has_key?(json, "errors")
      assert Map.has_key?(json, "performance")
      assert Map.has_key?(json, "generated_at")
    end

    test "message counts are correct in JSON output" do
      json = Formatter.to_json(sample_stats())

      assert json["messages"]["total"] == 3
      assert json["commands"]["total"] == 2
      assert json["errors"]["total"] == 1
    end

    test "can be encoded with Jason" do
      json = Formatter.to_json(sample_stats())

      assert {:ok, encoded} = Jason.encode(json)
      assert is_binary(encoded)
    end

    test "performance data has correct structure" do
      json = Formatter.to_json(sample_stats())
      perf = json["performance"]

      assert Map.has_key?(perf, "avg_response_time")
      assert Map.has_key?(perf, "p50")
      assert Map.has_key?(perf, "p95")
      assert Map.has_key?(perf, "p99")
      assert Map.has_key?(perf, "min")
      assert Map.has_key?(perf, "max")
    end

    test "handles empty stats" do
      json = Formatter.to_json(empty_stats())

      assert json["messages"]["total"] == 0
      assert json["performance"]["min"] == 0
    end
  end
end
