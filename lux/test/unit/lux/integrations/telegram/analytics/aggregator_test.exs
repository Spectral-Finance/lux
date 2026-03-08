defmodule Lux.Integrations.Telegram.Analytics.AggregatorTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.Analytics.Aggregator

  test "performance_metrics calculates correctly" do
    times = Enum.map(1..100, fn i -> {"/send", i, DateTime.utc_now()} end)
    metrics = Aggregator.performance_metrics(times)

    assert metrics.count == 100
    assert metrics.avg == 50.5
    assert metrics.min == 1
    assert metrics.max == 100
    assert metrics.p50 in 49..51
    assert metrics.p95 in 94..96
  end

  test "performance_metrics handles empty list" do
    metrics = Aggregator.performance_metrics([])
    assert metrics.count == 0
    assert metrics.avg == 0.0
  end

  test "error_rate calculation" do
    assert Aggregator.error_rate(5, 100) == 5.0
    assert Aggregator.error_rate(0, 100) == 0.0
    assert Aggregator.error_rate(1, 0) == 0.0
  end

  test "messages_per_user calculation" do
    assert Aggregator.messages_per_user(100, 10) == 10.0
    assert Aggregator.messages_per_user(50, 0) == 0.0
  end

  test "peak_hours finds top hours" do
    dist = %{9 => 50, 14 => 80, 20 => 100, 3 => 5, 12 => 60}
    peaks = Aggregator.peak_hours(dist)
    assert length(peaks) == 3
    assert hd(peaks).hour == 20
    assert hd(peaks).messages == 100
  end

  test "peak_hours handles empty" do
    assert Aggregator.peak_hours(%{}) == []
  end

  test "full report from collector" do
    name = :"agg_test_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = Lux.Integrations.Telegram.Analytics.Collector.start_link(name: name)
    alias Lux.Integrations.Telegram.Analytics.Collector

    Collector.track_message(pid, %{from_id: 1, chat_id: -100})
    Collector.track_command(pid, "/start", 1, -100)
    Collector.track_error(pid, :timeout)
    Process.sleep(10)

    {:ok, report} = Aggregator.report(pid)
    assert report.overview.total_messages == 1
    assert report.overview.total_commands == 1
    assert report.overview.total_errors == 1
    assert report.errors.total == 1
  end
end
