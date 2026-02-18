defmodule Lux.Lenses.Telegram.MetricReaderTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Lenses.Telegram.MetricReader
  alias Lux.Integrations.Telegram.Analytics

  setup do
    start_supervised!({Analytics, [name: :"test_#{:erlang.unique_integer([:positive])}", cleanup_interval_ms: 0]})
    Analytics.reset()
    :ok
  end

  describe "focus/2 - custom metric" do
    test "reads a custom metric value" do
      Analytics.define_custom_metric(:quality, :gauge, "Quality score")
      Analytics.record_custom_metric(:quality, 9.0)

      assert {:ok, %{name: "quality", value: 9.0}} =
               MetricReader.focus(%{metric: "custom", name: "quality"})
    end

    test "returns error for undefined custom metric" do
      assert {:error, "Custom metric 'nonexistent' not found"} =
               MetricReader.focus(%{metric: "custom", name: "nonexistent"})
    end

    test "returns error when name not provided" do
      assert {:error, "Missing 'name' parameter for custom metric"} =
               MetricReader.focus(%{metric: "custom"})
    end
  end

  describe "focus/2 - custom_list" do
    test "lists all custom metrics" do
      Analytics.define_custom_metric(:m1, :counter, "A")
      Analytics.define_custom_metric(:m2, :gauge, "B")

      assert {:ok, %{metrics: metrics}} = MetricReader.focus(%{metric: "custom_list"})
      assert length(metrics) == 2
    end

    test "returns empty list when no metrics" do
      assert {:ok, %{metrics: []}} = MetricReader.focus(%{metric: "custom_list"})
    end
  end

  describe "focus/2 - report" do
    test "generates a formatted report" do
      Analytics.record_message(:sent, %{})

      assert {:ok, %{report: report}} = MetricReader.focus(%{metric: "report"})
      assert is_binary(report)
      assert String.contains?(report, "📊 TELEGRAM BOT ANALYTICS REPORT")
    end
  end

  describe "focus/2 - export" do
    test "exports all analytics data" do
      Analytics.record_message(:sent, %{chat_id: 123})

      assert {:ok, export} = MetricReader.focus(%{metric: "export"})
      assert Map.has_key?(export, :events)
      assert Map.has_key?(export, :counters)
      assert Map.has_key?(export, :exported_at)
    end
  end

  describe "focus/2 - default" do
    test "defaults to custom_list" do
      assert {:ok, %{metrics: _}} = MetricReader.focus(%{})
    end
  end

  describe "focus/2 - unknown metric" do
    test "returns error for unknown metric type" do
      assert {:error, "Unknown metric type: invalid"} =
               MetricReader.focus(%{metric: "invalid"})
    end
  end

  describe "view/0" do
    test "returns a valid lens struct" do
      lens = MetricReader.view()
      assert lens.name == "Telegram Metric Reader"
      assert lens.method == :get
      assert Map.has_key?(lens.schema.properties, :metric)
      assert Map.has_key?(lens.schema.properties, :name)
    end
  end
end
