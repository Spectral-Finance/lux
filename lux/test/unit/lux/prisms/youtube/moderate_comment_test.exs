defmodule Lux.Prisms.YouTube.ModerateCommentTest do
  @moduledoc """
  Test suite for the ModerateComment prism.
  These tests verify the prism's ability to:
  - Apply spam detection to comment text
  - Apply the requested moderation action
  - Return structured moderation results with confidence scores
  - Detect toxic content
  """

  use UnitCase, async: true
  alias Lux.Prisms.YouTube.ModerateComment

  describe "handler/2" do
    test "rejects comment with spam content" do
      assert {:ok, result} =
               ModerateComment.handler(
                 %{
                   "comment_id" => "comment_123",
                   "comment_text" => "Subscribe to me for free money!",
                   "action" => "reject"
                 },
                 %{}
               )

      assert result.comment_id == "comment_123"
      assert result.action == "reject"
      assert result.moderation_result == "rejected"
      assert result.is_spam == true
      assert "spam_detected" in result.reasons
      assert result.confidence > 0.85
    end

    test "approves clean comment" do
      assert {:ok, result} =
               ModerateComment.handler(
                 %{
                   "comment_id" => "comment_456",
                   "comment_text" => "This is a thoughtful and engaging comment about the video.",
                   "action" => "approve"
                 },
                 %{}
               )

      assert result.moderation_result == "approved"
      assert result.is_spam == false
      assert result.is_toxic == false
      assert "content_meets_guidelines" in result.reasons
    end

    test "holds spam when action is approve" do
      assert {:ok, result} =
               ModerateComment.handler(
                 %{
                   "comment_id" => "comment_789",
                   "comment_text" => "Check out my channel for more!",
                   "action" => "approve"
                 },
                 %{}
               )

      assert result.moderation_result == "held"
      assert result.is_spam == true
    end

    test "holds comment on manual hold action" do
      assert {:ok, result} =
               ModerateComment.handler(
                 %{
                   "comment_id" => "comment_999",
                   "comment_text" => "Needs manual review.",
                   "action" => "hold"
                 },
                 %{}
               )

      assert result.moderation_result == "held"
      assert "manual_review_requested" in result.reasons
    end

    test "detects toxic content" do
      assert {:ok, result} =
               ModerateComment.handler(
                 %{
                   "comment_id" => "comment_toxic",
                   "comment_text" => "This is stupid and garbage content",
                   "action" => "reject"
                 },
                 %{}
               )

      assert result.is_toxic == true
      assert "toxic_content" in result.reasons
    end

    test "returns confidence score between 0 and 1" do
      assert {:ok, result} =
               ModerateComment.handler(
                 %{
                   "comment_id" => "c1",
                   "comment_text" => "Normal comment",
                   "action" => "approve"
                 },
                 %{}
               )

      assert result.confidence >= 0.0
      assert result.confidence <= 1.0
    end
  end

  describe "schema validation" do
    test "validates input schema required fields" do
      prism = ModerateComment.view()
      assert "comment_id" in prism.input_schema.required
      assert "comment_text" in prism.input_schema.required
      assert "action" in prism.input_schema.required
    end

    test "validates action enum values" do
      prism = ModerateComment.view()
      action_prop = prism.input_schema.properties.action
      assert "approve" in action_prop.enum
      assert "reject" in action_prop.enum
      assert "hold" in action_prop.enum
    end
  end
end
