defmodule Lux.YouTube.ContentIntelligence.PerformanceAnalyticsTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentIntelligence.PerformanceAnalytics

  describe "happy_path" do
    test "analyzes video performance with valid data" do
      input = %{
        views: 10_000,
        watch_time_minutes: 5000,
        video_length_seconds: 600,
        likes: 500,
        comments: 50,
        shares: 25,
        published_at: ~U[2024-01-01 12:00:00Z],
        current_time: ~U[2024-01-02 12:00:00Z]
      }

      {:ok, result} = PerformanceAnalytics.analyze(input)

      assert result.view_velocity_per_hour > 0
      assert result.view_velocity_per_hour == 416.67
      assert length(result.retention_curve) == 11
      assert is_list(result.drop_off_points)
      assert result.benchmark_multiplier > 0
      assert result.engagement_rate >= 0
      assert result.watch_time_percentage >= 0
    end

    test "calculates view velocity correctly" do
      result = PerformanceAnalytics.view_velocity(1000, 5.0)
      assert result == 200.0
    end

    test "returns zero velocity for zero hours elapsed" do
      result = PerformanceAnalytics.view_velocity(1000, 0)
      assert result == 0.0
    end

    test "generates retention curve with correct structure" do
      curve = PerformanceAnalytics.retention_curve(500, 600)
      assert length(curve) == 11
      assert hd(curve)["percentage"] == 100.0
      Enum.each(curve, fn point ->
        assert point["percentage"] >= 0
        assert point["percentage"] <= 100
      end)
    end

    test "detects drop off points in retention curve" do
      curve = [%{"time" => 0, "percentage" => 100.0},
               %{"time" => 60, "percentage" => 85.0},
               %{"time" => 120, "percentage" => 84.0}]
      drops = PerformanceAnalytics.detect_drop_off_points(curve)
      assert length(drops) == 1
      assert hd(drops)["drop_percentage"] == 15.0
    end

    test "calculates benchmark multiplier" do
      result = PerformanceAnalytics.benchmark_multiplier(100.0, 50.0)
      assert result == 2.0
    end

    test "returns 1.0 multiplier when channel average is zero" do
      result = PerformanceAnalytics.benchmark_multiplier(100.0, 0.0)
      assert result == 1.0
    end
  end

  describe "boundary" do
    test "handles zero views" do
      input = %{
        views: 0,
        watch_time_minutes: 0,
        video_length_seconds: 600,
        published_at: ~U[2024-01-01 12:00:00Z],
        current_time: ~U[2024-01-02 12:00:00Z],
        likes: 0,
        comments: 0,
        shares: 0
      }

      {:ok, result} = PerformanceAnalytics.analyze(input)
      assert result.view_velocity_per_hour == 0.0
      assert result.engagement_rate == 0.0
    end

    test "handles minimum video length (1 second)" do
      input = %{
        views: 100,
        watch_time_minutes: 1,
        video_length_seconds: 1,
        published_at: ~U[2024-01-01 12:00:00Z],
        current_time: ~U[2024-01-01 12:00:01Z],
        likes: 0,
        comments: 0,
        shares: 0
      }

      {:ok, result} = PerformanceAnalytics.analyze(input)
      assert result.view_velocity_per_hour > 0
    end

    test "handles same published and current time (0 hours elapsed)" do
      input = %{
        views: 1000,
        watch_time_minutes: 100,
        video_length_seconds: 600,
        published_at: ~U[2024-01-01 12:00:00Z],
        current_time: ~U[2024-01-01 12:00:00Z],
        likes: 0,
        comments: 0,
        shares: 0
      }

      {:ok, result} = PerformanceAnalytics.analyze(input)
      assert result.view_velocity_per_hour == 0.0
    end
  end

  describe "null_input" do
    test "returns error for nil input" do
      assert {:error, :invalid_input} = PerformanceAnalytics.analyze(nil)
    end

    test "returns error for non-map input" do
      assert {:error, :invalid_input} = PerformanceAnalytics.analyze("not_a_map")
    end

    test "returns error for missing required fields" do
      input = %{views: 1000}
      assert {:error, {:missing_fields, _}} = PerformanceAnalytics.analyze(input)
    end
  end

  describe "empty_input" do
    test "rejects empty map input" do
      assert {:error, {:missing_fields, _}} = PerformanceAnalytics.analyze(%{})
    end

    test "rejects negative views" do
      input = %{
        views: -1,
        watch_time_minutes: 100,
        video_length_seconds: 600,
        published_at: ~U[2024-01-01 12:00:00Z],
        current_time: ~U[2024-01-02 12:00:00Z],
        likes: 0,
        comments: 0,
        shares: 0
      }

      assert {:error, {:invalid_value, :views}} = PerformanceAnalytics.analyze(input)
    end

    test "rejects zero or negative video length" do
      input = %{
        views: 1000,
        watch_time_minutes: 100,
        video_length_seconds: 0,
        published_at: ~U[2024-01-01 12:00:00Z],
        current_time: ~U[2024-01-02 12:00:00Z],
        likes: 0,
        comments: 0,
        shares: 0
      }

      assert {:error, {:invalid_value, :video_length_seconds}} = PerformanceAnalytics.analyze(input)
    end
  end

  describe "negative" do
    test "rejects negative watch time" do
      input = %{
        views: 1000,
        watch_time_minutes: -100,
        video_length_seconds: 600,
        published_at: ~U[2024-01-01 12:00:00Z],
        current_time: ~U[2024-01-02 12:00:00Z],
        likes: 0,
        comments: 0,
        shares: 0
      }

      assert {:error, {:invalid_value, :watch_time_minutes}} = PerformanceAnalytics.analyze(input)
    end
  end
end