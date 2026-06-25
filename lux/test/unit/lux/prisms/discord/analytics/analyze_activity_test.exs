defmodule Lux.Prisms.Discord.Analytics.AnalyzeActivityTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Discord.Analytics.AnalyzeActivity

  @agent_ctx %{agent: %{name: "TestAgent"}}

  describe "handler/2" do
    test "analyzes event list" do
      events = [
        %{type: :message, user_id: "u1", channel_id: "c1", timestamp: ~U[2026-01-01 14:00:00Z], metadata: %{}},
        %{type: :message, user_id: "u2", channel_id: "c1", timestamp: ~U[2026-01-01 15:00:00Z], metadata: %{}},
        %{type: :voice, user_id: "u1", channel_id: "vc1", timestamp: ~U[2026-01-01 14:30:00Z], metadata: %{action: :join}}
      ]

      {:ok, result} = AnalyzeActivity.handler(%{events: events}, @agent_ctx)
      assert result.total_events == 3
      assert result.by_type[:message] == 2
      assert result.by_type[:voice] == 1
      assert result.peak_hour == 14
    end

    test "handles empty event list" do
      {:ok, result} = AnalyzeActivity.handler(%{events: []}, @agent_ctx)
      assert result.total_events == 0
      assert result.peak_hour == nil
    end

    test "returns error when events is missing" do
      {:error, "Missing events parameter"} = AnalyzeActivity.handler(%{}, @agent_ctx)
    end

    test "returns error when events is not a list" do
      {:error, "Events must be a list"} = AnalyzeActivity.handler(%{events: "not a list"}, @agent_ctx)
    end

    test "handles events with string keys" do
      events = [
        %{"type" => :message, "user_id" => "u1", "channel_id" => "c1", "timestamp" => ~U[2026-01-01 14:00:00Z], "metadata" => %{}}
      ]

      {:ok, result} = AnalyzeActivity.handler(%{events: events}, @agent_ctx)
      assert result.total_events == 1
    end

    test "handles events with nil timestamps" do
      events = [
        %{type: :message, user_id: "u1", channel_id: "c1", timestamp: nil, metadata: %{}},
        %{type: :message, user_id: "u1", channel_id: "c1", timestamp: ~U[2026-01-01 14:00:00Z], metadata: %{}}
      ]

      {:ok, result} = AnalyzeActivity.handler(%{events: events}, @agent_ctx)
      assert result.total_events == 2
      assert result.by_hour == %{14 => 1}
    end

    test "handles NaiveDateTime timestamps" do
      events = [
        %{type: :message, user_id: "u1", channel_id: "c1", timestamp: ~N[2026-01-01 14:00:00], metadata: %{}}
      ]

      {:ok, result} = AnalyzeActivity.handler(%{events: events}, @agent_ctx)
      assert result.total_events == 1
      assert result.peak_hour == 14
    end
  end
end
