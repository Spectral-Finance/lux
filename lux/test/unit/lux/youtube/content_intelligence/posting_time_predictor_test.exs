defmodule Lux.YouTube.ContentIntelligence.PostingTimePredictorTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentIntelligence.PostingTimePredictor

  describe "happy_path" do
    test "predicts optimal posting times with valid data" do
      input = %{
        historical_performance: [
          %{hour: 18, day_of_week: 1, views: 5000},
          %{hour: 19, day_of_week: 1, views: 7000},
          %{hour: 20, day_of_week: 1, views: 9000},
          %{hour: 18, day_of_week: 6, views: 3000},
          %{hour: 19, day_of_week: 6, views: 4000}
        ],
        timezone: "UTC",
        lead_time_hours: 24
      }

      {:ok, result} = PostingTimePredictor.predict(input)

      assert is_list(result.peak_viewer_activity)
      assert is_list(result.recommended_slots)
      assert is_list(result.timezone_weighted_times)
      assert is_list(result.heatmap)
      assert result.lead_time_buffer == 24
    end

    test "builds heatmap from performance data" do
      data = [%{hour: 18, day_of_week: 1, views: 5000},
              %{hour: 18, day_of_week: 1, views: 7000}]

      result = PostingTimePredictor.build_heatmap(data)
      assert length(result) == 1
      assert hd(result)["avg_views"] == 6000
    end

    test "identifies peak times" do
      heatmap = [%{"hour" => 20, "day_of_week" => 1, "avg_views" => 9000},
                 %{"hour" => 19, "day_of_week" => 1, "avg_views" => 7000}]

      result = PostingTimePredictor.identify_peak_times(heatmap)
      assert length(result) == 2
      assert hd(result)["hour"] == 20
    end

    test "scores time slots" do
      heatmap = [%{"hour" => 20, "day_of_week" => 1, "avg_views" => 9000}]
      result = PostingTimePredictor.score_slots(heatmap, "UTC", 24)
      assert length(result) == 1
      assert hd(result)["score"] > 0
    end

    test "adjusts for timezone" do
      heatmap = [%{"hour" => 18, "day_of_week" => 1, "avg_views" => 9000}]
      result = PostingTimePredictor.adjust_for_timezone(heatmap, "EST")
      assert length(result) == 1
      assert hd(result)["hour"] == 13  # 18 - 5 = 13
    end
  end

  describe "boundary" do
    test "handles empty historical performance" do
      input = %{
        historical_performance: [],
        timezone: "UTC"
      }

      {:ok, result} = PostingTimePredictor.predict(input)
      assert result.peak_viewer_activity == []
      assert result.recommended_slots == []
    end

    test "handles zero lead time" do
      input = %{
        historical_performance: [%{hour: 18, day_of_week: 1, views: 5000}],
        timezone: "UTC",
        lead_time_hours: 0
      }

      {:ok, result} = PostingTimePredictor.predict(input)
      assert result.lead_time_buffer == 0
    end
  end

  describe "null_input" do
    test "returns error for nil input" do
      assert {:error, :invalid_input} = PostingTimePredictor.predict(nil)
    end

    test "returns error for missing required fields" do
      input = %{timezone: "UTC"}
      assert {:error, {:missing_fields, _}} = PostingTimePredictor.predict(input)
    end
  end

  describe "empty_input" do
    test "rejects empty map input" do
      assert {:error, {:missing_fields, _}} = PostingTimePredictor.predict(%{})
    end

    test "rejects non-list historical_performance" do
      input = %{historical_performance: "not_a_list", timezone: "UTC"}
      assert {:error, {:invalid_value, :historical_performance}} = PostingTimePredictor.predict(input)
    end
  end

  describe "negative" do
    test "rejects non-binary timezone" do
      input = %{historical_performance: [], timezone: 123}
      assert {:error, {:invalid_value, :timezone}} = PostingTimePredictor.predict(input)
    end
  end
end