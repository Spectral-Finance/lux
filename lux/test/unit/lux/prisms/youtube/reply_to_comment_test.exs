defmodule Lux.Prisms.YouTube.ReplyToCommentTest do
  @moduledoc """
  Test suite for the ReplyToComment prism.
  These tests verify the prism's ability to:
  - Generate personalized reply suggestions
  - Classify reply types correctly
  - Estimate engagement boost
  - Validate character limit compliance
  """

  use UnitCase, async: true
  alias Lux.Prisms.YouTube.ReplyToComment

  describe "handler/2" do
    test "generates a basic reply with channel attribution" do
      assert {:ok, result} =
               ReplyToComment.handler(
                 %{
                   "thread_id" => "thread_123",
                   "reply_text" => "Thank you for watching!",
                   "channel_name" => "TechChannel"
                 },
                 %{}
               )

      assert result.thread_id == "thread_123"
      assert result.channel_name == "TechChannel"
      assert String.contains?(result.suggested_reply, "TechChannel")
      assert result.character_count > 0
      assert result.within_limit == true
    end

    test "classifies gratitude replies correctly" do
      assert {:ok, result} =
               ReplyToComment.handler(
                 %{
                   "thread_id" => "t1",
                   "reply_text" => "We really appreciate your support!",
                   "channel_name" => "MyChannel"
                 },
                 %{}
               )

      assert result.reply_type == "gratitude"
      assert result.estimated_engagement_boost > 0
    end

    test "classifies engagement replies correctly" do
      assert {:ok, result} =
               ReplyToComment.handler(
                 %{
                   "thread_id" => "t2",
                   "reply_text" => "What do you think about this topic?",
                   "channel_name" => "MyChannel"
                 },
                 %{}
               )

      assert result.reply_type == "engagement"
      assert result.estimated_engagement_boost >= 0.18
    end

    test "boosts engagement for positive original comment" do
      assert {:ok, result_positive} =
               ReplyToComment.handler(
                 %{
                   "thread_id" => "t3",
                   "reply_text" => "Thanks!",
                   "channel_name" => "MyChannel",
                   "original_comment" => "This is amazing content I love it!"
                 },
                 %{}
               )

      assert {:ok, result_generic} =
               ReplyToComment.handler(
                 %{
                   "thread_id" => "t4",
                   "reply_text" => "Thanks!",
                   "channel_name" => "MyChannel",
                   "original_comment" => "ok video"
                 },
                 %{}
               )

      assert result_positive.estimated_engagement_boost >=
               result_generic.estimated_engagement_boost
    end

    test "returns character count and within_limit flag" do
      assert {:ok, result} =
               ReplyToComment.handler(
                 %{
                   "thread_id" => "t5",
                   "reply_text" => "Short reply",
                   "channel_name" => "Chan"
                 },
                 %{}
               )

      assert is_integer(result.character_count)
      assert result.within_limit == true
    end

    test "engagement_boost is between 0 and 1" do
      assert {:ok, result} =
               ReplyToComment.handler(
                 %{
                   "thread_id" => "t6",
                   "reply_text" => "Reply text here",
                   "channel_name" => "Channel"
                 },
                 %{}
               )

      assert result.estimated_engagement_boost >= 0.0
      assert result.estimated_engagement_boost <= 1.0
    end
  end

  describe "schema validation" do
    test "validates required input fields" do
      prism = ReplyToComment.view()
      assert "thread_id" in prism.input_schema.required
      assert "reply_text" in prism.input_schema.required
      assert "channel_name" in prism.input_schema.required
    end

    test "validates output schema required fields" do
      prism = ReplyToComment.view()
      assert "thread_id" in prism.output_schema.required
      assert "suggested_reply" in prism.output_schema.required
      assert "estimated_engagement_boost" in prism.output_schema.required
    end
  end
end
