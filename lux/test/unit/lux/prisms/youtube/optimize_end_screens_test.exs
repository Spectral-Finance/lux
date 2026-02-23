defmodule Lux.Prisms.YouTube.OptimizeEndScreensTest do
  @moduledoc """
  Test suite for the OptimizeEndScreens prism.
  These tests verify the prism's ability to:
  - Generate optimized end screen layouts with correct timing
  - Include all four recommended elements for full channels
  - Handle videos with and without top-performing video data
  - Validate required parameters (video_id, video_duration_seconds)
  - Reject videos that are too short for end screens
  - Provide actionable optimization tips
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.YouTube.OptimizeEndScreens

  @video_id "dQw4w9WgXcQ"
  @channel_id "UCxxxxxx1234567890"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  describe "handler/2" do
    test "generates optimized end screen for a standard video with top videos" do
      assert {:ok, result} =
               OptimizeEndScreens.handler(
                 %{
                   "video_id" => @video_id,
                   "video_duration_seconds" => 213,
                   "channel_id" => @channel_id,
                   "top_performing_videos" => [
                     %{"id" => "abc123", "title" => "Best Tutorial Ever"}
                   ]
                 },
                 @agent_ctx
               )

      assert result.video_id == @video_id
      assert result.start_at_seconds == 193
      assert result.duration_seconds == 20
      assert result.element_count == 4
      assert is_list(result.elements)
      assert is_binary(result.expected_ctr_boost)
      assert is_list(result.optimization_tips)
      assert length(result.optimization_tips) > 0
    end

    test "calculates correct start_at_seconds (duration minus 20)" do
      assert {:ok, result} =
               OptimizeEndScreens.handler(
                 %{
                   "video_id" => @video_id,
                   "video_duration_seconds" => 600
                 },
                 @agent_ctx
               )

      assert result.start_at_seconds == 580
    end

    test "includes subscribe button as first-priority element" do
      assert {:ok, result} =
               OptimizeEndScreens.handler(
                 %{
                   "video_id" => @video_id,
                   "video_duration_seconds" => 300
                 },
                 @agent_ctx
               )

      subscribe_element = Enum.find(result.elements, &(&1.type == "subscribe"))
      assert subscribe_element != nil
      assert subscribe_element.priority == 1
    end

    test "includes latest video card" do
      assert {:ok, result} =
               OptimizeEndScreens.handler(
                 %{
                   "video_id" => @video_id,
                   "video_duration_seconds" => 120
                 },
                 @agent_ctx
               )

      latest = Enum.find(result.elements, &(Map.get(&1, :subtype) == "latest"))
      assert latest != nil
      assert latest.type == "video"
    end

    test "includes best_for_viewer card with top video reference when provided" do
      assert {:ok, result} =
               OptimizeEndScreens.handler(
                 %{
                   "video_id" => @video_id,
                   "video_duration_seconds" => 300,
                   "top_performing_videos" => [
                     %{"id" => "top001", "title" => "Top Video"}
                   ]
                 },
                 @agent_ctx
               )

      bfv = Enum.find(result.elements, &(Map.get(&1, :subtype) == "best_for_viewer"))
      assert bfv != nil
      assert bfv.video_id == "top001"
    end

    test "omits playlist element when no channel_id is provided" do
      assert {:ok, result} =
               OptimizeEndScreens.handler(
                 %{
                   "video_id" => @video_id,
                   "video_duration_seconds" => 300
                 },
                 @agent_ctx
               )

      playlist = Enum.find(result.elements, &(&1.type == "playlist"))
      assert playlist == nil
      assert result.element_count == 3
    end

    test "returns error for missing video_id" do
      assert {:error, message} =
               OptimizeEndScreens.handler(
                 %{"video_duration_seconds" => 300},
                 @agent_ctx
               )

      assert String.contains?(message, "video_id")
    end

    test "returns error for missing video_duration_seconds" do
      assert {:error, message} =
               OptimizeEndScreens.handler(
                 %{"video_id" => @video_id},
                 @agent_ctx
               )

      assert String.contains?(message, "video_duration_seconds")
    end

    test "returns error for video shorter than 25 seconds" do
      assert {:error, message} =
               OptimizeEndScreens.handler(
                 %{
                   "video_id" => @video_id,
                   "video_duration_seconds" => 20
                 },
                 @agent_ctx
               )

      assert String.contains?(message, "25 seconds")
    end

    test "includes additional tip for long videos (over 5 minutes)" do
      assert {:ok, result} =
               OptimizeEndScreens.handler(
                 %{
                   "video_id" => @video_id,
                   "video_duration_seconds" => 600
                 },
                 @agent_ctx
               )

      chapter_tip = Enum.find(result.optimization_tips, &String.contains?(&1, "chapter"))
      assert chapter_tip != nil
    end
  end
end
