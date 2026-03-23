defmodule Lux.Integrations.Telegram.Analytics.AggregatorTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias Lux.Integrations.Telegram.Analytics.Aggregator

  defp make_event(datetime) do
    %{timestamp: datetime, type: :text, chat_id: 1}
  end

  defp make_events_at_hours(hours) do
    Enum.map(hours, fn hour ->
      {:ok, dt} = DateTime.new(~D[2024-06-15], Time.new!(hour, 0, 0), "Etc/UTC")
      make_event(dt)
    end)
  end

  describe "aggregate/2" do
    test "aggregates events by hour" do
      events = make_events_at_hours([10, 10, 10, 14, 14, 18])

      result = Aggregator.aggregate(events, :hourly)

      assert result[{2024, 6, 15, 10}] == 3
      assert result[{2024, 6, 15, 14}] == 2
      assert result[{2024, 6, 15, 18}] == 1
    end

    test "aggregates events by day" do
      events = [
        make_event(~U[2024-06-15 10:00:00Z]),
        make_event(~U[2024-06-15 14:00:00Z]),
        make_event(~U[2024-06-16 10:00:00Z])
      ]

      result = Aggregator.aggregate(events, :daily)

      assert result[{2024, 6, 15}] == 2
      assert result[{2024, 6, 16}] == 1
    end

    test "aggregates events by week" do
      events = [
        make_event(~U[2024-06-10 10:00:00Z]),
        make_event(~U[2024-06-11 10:00:00Z]),
        make_event(~U[2024-06-17 10:00:00Z])
      ]

      result = Aggregator.aggregate(events, :weekly)

      assert map_size(result) >= 1
    end

    test "handles empty list" do
      assert Aggregator.aggregate([], :hourly) == %{}
    end
  end

  describe "calculate_rate/2" do
    test "calculates rate per hour" do
      events = [
        make_event(~U[2024-06-15 10:00:00Z]),
        make_event(~U[2024-06-15 11:00:00Z]),
        make_event(~U[2024-06-15 12:00:00Z]),
        make_event(~U[2024-06-15 13:00:00Z])
      ]

      rate = Aggregator.calculate_rate(events, :per_hour)
      assert_in_delta rate, 1.33, 0.1
    end

    test "calculates rate per minute" do
      events = [
        make_event(~U[2024-06-15 10:00:00Z]),
        make_event(~U[2024-06-15 10:01:00Z]),
        make_event(~U[2024-06-15 10:02:00Z])
      ]

      rate = Aggregator.calculate_rate(events, :per_minute)
      assert_in_delta rate, 1.5, 0.1
    end

    test "returns 0.0 for empty list" do
      assert Aggregator.calculate_rate([], :per_hour) == 0.0
    end
  end

  describe "calculate_percentile/2" do
    test "calculates p50 (median)" do
      values = [10, 20, 30, 40, 50]
      assert Aggregator.calculate_percentile(values, 50) == 30
    end

    test "calculates p95" do
      values = Enum.to_list(1..100)
      assert Aggregator.calculate_percentile(values, 95) == 95
    end

    test "calculates p99" do
      values = Enum.to_list(1..100)
      assert Aggregator.calculate_percentile(values, 99) == 99
    end

    test "handles single value" do
      assert Aggregator.calculate_percentile([42], 50) == 42
      assert Aggregator.calculate_percentile([42], 99) == 42
    end

    test "returns 0 for empty list" do
      assert Aggregator.calculate_percentile([], 50) == 0
    end

    test "calculates p0 (minimum)" do
      values = [10, 20, 30, 40, 50]
      assert Aggregator.calculate_percentile(values, 0) == 10
    end

    test "calculates p100 (maximum)" do
      values = [10, 20, 30, 40, 50]
      assert Aggregator.calculate_percentile(values, 100) == 50
    end
  end

  describe "calculate_trend/2" do
    test "detects increasing trend" do
      events =
        [
          make_event(~U[2024-06-15 10:00:00Z]),
          make_event(~U[2024-06-15 11:00:00Z]),
          make_event(~U[2024-06-15 11:01:00Z]),
          make_event(~U[2024-06-15 12:00:00Z]),
          make_event(~U[2024-06-15 12:01:00Z]),
          make_event(~U[2024-06-15 12:02:00Z])
        ]

      assert Aggregator.calculate_trend(events, :hourly) == :increasing
    end

    test "detects decreasing trend" do
      events =
        [
          make_event(~U[2024-06-15 10:00:00Z]),
          make_event(~U[2024-06-15 10:01:00Z]),
          make_event(~U[2024-06-15 10:02:00Z]),
          make_event(~U[2024-06-15 11:00:00Z]),
          make_event(~U[2024-06-15 11:01:00Z]),
          make_event(~U[2024-06-15 12:00:00Z])
        ]

      assert Aggregator.calculate_trend(events, :hourly) == :decreasing
    end

    test "returns stable for empty list" do
      assert Aggregator.calculate_trend([], :hourly) == :stable
    end

    test "returns stable for single bucket" do
      events = [make_event(~U[2024-06-15 10:00:00Z])]
      assert Aggregator.calculate_trend(events, :hourly) == :stable
    end
  end

  describe "peak_hours/1" do
    test "identifies peak hours" do
      events = make_events_at_hours([10, 10, 10, 14, 14, 18, 10])

      result = Aggregator.peak_hours(events)

      assert hd(result) == {10, 4}
    end

    test "returns empty for no events" do
      assert Aggregator.peak_hours([]) == []
    end
  end

  describe "group_by_key/2" do
    test "groups events by a specified key" do
      events = [
        %{type: :text, chat_id: 1},
        %{type: :photo, chat_id: 2},
        %{type: :text, chat_id: 3}
      ]

      result = Aggregator.group_by_key(events, :type)

      assert result[:text] == 2
      assert result[:photo] == 1
    end

    test "handles empty list" do
      assert Aggregator.group_by_key([], :type) == %{}
    end
  end

  describe "detect_anomalies/2" do
    test "detects anomalous spikes" do
      # Create normal traffic (1-2 per hour) with one huge spike
      normal_events = make_events_at_hours([10, 11, 12, 13])

      # Spike at hour 14 with many events
      {:ok, spike_dt} = DateTime.new(~D[2024-06-15], Time.new!(14, 0, 0), "Etc/UTC")
      spike_events = for _ <- 1..20, do: make_event(spike_dt)

      all_events = normal_events ++ spike_events
      anomalies = Aggregator.detect_anomalies(all_events, :hourly)

      assert length(anomalies) >= 1
      assert {_, 20} = hd(anomalies)
    end

    test "returns empty for empty events" do
      assert Aggregator.detect_anomalies([], :hourly) == []
    end
  end
end
