defmodule Lux.YouTube.ContentIntelligence.PostingTimePredictorTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentIntelligence.PostingTimePredictor

  describe "predict_optimal_time/1" do
    test "predicts optimal day and utc hour for America/New_York" do
      result = PostingTimePredictor.predict_optimal_time(%{timezone: "America/New_York"})

      assert result.recommended_day_of_week == :thursday
      assert result.recommended_utc_hour == 19
      assert result.audience_activity_index > 80.0
      assert result.recommended_lead_time_minutes == 45
    end

    test "predicts weekend slot when requested" do
      result = PostingTimePredictor.predict_optimal_time(%{day_preference: :weekend})

      assert result.recommended_day_of_week == :saturday
      assert result.recommended_utc_hour == 14
    end
  end

  describe "score_scheduled_slot/1" do
    test "scores peak afternoon hour as optimal" do
      {:ok, peak_dt, _} = DateTime.from_iso8601("2026-11-05T18:00:00Z")
      scored = PostingTimePredictor.score_scheduled_slot(peak_dt)

      assert scored.recommendation == :optimal
      assert scored.score >= 85.0
    end

    test "scores middle of night slot as suboptimal" do
      {:ok, night_dt, _} = DateTime.from_iso8601("2026-11-05T06:00:00Z")
      scored = PostingTimePredictor.score_scheduled_slot(night_dt)

      assert scored.recommendation == :suboptimal
      assert scored.score < 60.0
    end
  end
end
