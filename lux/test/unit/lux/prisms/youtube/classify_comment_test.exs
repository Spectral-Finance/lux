defmodule Lux.Prisms.YouTube.ClassifyCommentTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.YouTube.ClassifyComment

  describe "handler/2" do
    test "classifies a scam link comment to hide" do
      comment = %{
        text: "whatsapp me on +1234567 for guaranteed crypto profit",
        author_display_name: "Scammer"
      }

      assert {:ok, %{
        state: "hide",
        sentiment: "negative",
        confidence: 0.95,
        reasons: ["scam links / financial spam detected"],
        recommended_reply: nil
      }} = ClassifyComment.handler(comment, %{name: "TestAgent"})
    end

    test "classifies a links-only spam comment to hide" do
      comment = %{
        text: "https://spamlink.xyz/abc",
        author_display_name: "Spammer"
      }

      assert {:ok, %{
        state: "hide",
        sentiment: "neutral",
        confidence: 0.95,
        reasons: ["links-only spam detected"],
        recommended_reply: nil
      }} = ClassifyComment.handler(comment, %{name: "TestAgent"})
    end

    test "classifies abusive comment to hide" do
      comment = %{
        text: "This is absolute shit, you are a scumbag!",
        author_display_name: "Abuser"
      }

      assert {:ok, %{
        state: "hide",
        sentiment: "negative",
        confidence: 0.9,
        reasons: ["abusive / vulgar content detected"],
        recommended_reply: nil
      }} = ClassifyComment.handler(comment, %{name: "TestAgent"})
    end

    test "classifies technical issue/bug comment to escalate" do
      comment = %{
        text: "The page keeps crashing and showing an error.",
        author_display_name: "UserWithIssue"
      }

      assert {:ok, %{
        state: "escalate",
        sentiment: "negative",
        confidence: 0.85,
        reasons: ["technical support or system issue detected"],
        recommended_reply: nil
      }} = ClassifyComment.handler(comment, %{name: "TestAgent"})
    end

    test "classifies short low-engagement comment to no-action" do
      comment = %{
        text: "ok",
        author_display_name: "QuietUser"
      }

      assert {:ok, %{
        state: "no-action",
        sentiment: "neutral",
        confidence: 0.8,
        reasons: ["low-engagement neutral greeting/acknowledgement"],
        recommended_reply: nil
      }} = ClassifyComment.handler(comment, %{name: "TestAgent"})
    end

    test "classifies positive feedback to reply with template response" do
      comment = %{
        text: "This video is amazing! Thank you for the great and helpful content.",
        author_display_name: "HappyUser"
      }

      assert {:ok, %{
        state: "reply",
        sentiment: "positive",
        reasons: ["positive feedback"],
        recommended_reply: "Thank you so much for the support! Glad you found it helpful."
      }} = ClassifyComment.handler(comment, %{name: "TestAgent"})
    end

    test "falls back to review for neutral general comment" do
      comment = %{
        text: "What time is the next live stream?",
        author_display_name: "CuriousUser"
      }

      assert {:ok, %{
        state: "review",
        sentiment: "neutral",
        confidence: 0.5,
        reasons: ["unclassified comment pattern"],
        recommended_reply: nil
      }} = ClassifyComment.handler(comment, %{name: "TestAgent"})
    end
  end
end
