defmodule Lux.Prisms.YouTubeCommunityPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.YouTubeCommunityPrism

  describe "handler/2" do
    test "executes sentiment action successfully" do
      {:ok, response} =
        YouTubeCommunityPrism.run(%{
          action: "sentiment",
          payload: %{text: "This video was awesome and really helpful!"}
        })

      assert response.action == "sentiment"
      assert response.result.classification == :positive
      assert response.result.score > 0
      assert response.result.intent == :praise
    end

    test "executes moderate action successfully" do
      {:ok, response} =
        YouTubeCommunityPrism.run(%{
          action: "moderate",
          payload: %{text: "Join my crypto signal group now http://t.me/fakepump"}
        })

      assert response.action == "moderate"
      assert response.result.is_spam == true
      assert response.result.recommended_action in [:reject, :ban_author]
      assert length(response.result.reasons) > 0
    end

    test "executes reply action successfully" do
      {:ok, response} =
        YouTubeCommunityPrism.run(%{
          action: "reply",
          payload: %{
            text: "How do I install the dependencies?",
            author: "CodeLearner",
            persona: "Alex"
          }
        })

      assert response.action == "reply"
      assert is_binary(response.result)
      assert String.contains?(response.result, "CodeLearner")
    end

    test "executes process action on incoming comment" do
      {:ok, response} =
        YouTubeCommunityPrism.run(%{
          action: "process",
          payload: %{
            id: "yt_c_101",
            text: "Incredible explanation, thank you so much!",
            author_name: "HappyViewer"
          }
        })

      assert response.action == "process"
      assert response.result.moderation.is_spam == false
      assert response.result.sentiment.classification == :positive
      assert is_binary(response.result.suggested_reply)
    end

    test "executes schedule_post action" do
      now = DateTime.utc_now()
      scheduled_for = DateTime.add(now, 7200, :second)

      {:ok, response} =
        YouTubeCommunityPrism.run(%{
          action: "schedule_post",
          payload: %{
            content: "What topic should we cover in next week's stream?",
            type: :poll,
            options: ["Agent Prisms", "Elixir OTP", "EVM Bridges"],
            scheduled_at: scheduled_for
          }
        })

      assert response.action == "schedule_post"
      assert response.result.status == :scheduled
      assert length(response.result.options) == 3
    end

    test "executes batch_sentiment action" do
      comments = [
        %{text: "Loved this tutorial!"},
        %{text: "Horrible explanation, completely broke my build."},
        %{text: "Is there a repo for this?"}
      ]

      {:ok, response} =
        YouTubeCommunityPrism.run(%{
          action: "batch_sentiment",
          payload: %{comments: comments}
        })

      assert response.action == "batch_sentiment"
      assert response.result.total_analyzed == 3
      assert response.result.inquiry_count == 1
      assert response.result.positive_percentage > 0
      assert response.result.negative_percentage > 0
    end

    test "handles unknown action with error" do
      {:error, reason} =
        YouTubeCommunityPrism.run(%{
          action: "unsupported_command",
          payload: %{}
        })

      assert String.contains?(reason, "Unknown action: unsupported_command")
    end
  end

  describe "schema validation" do
    test "validates prism metadata and schema attributes" do
      prism = YouTubeCommunityPrism.view()
      assert prism.name == "YouTube Community Prism"
      assert prism.input_schema.required == ["action"]
      assert Map.has_key?(prism.input_schema.properties, :action)
      assert Map.has_key?(prism.input_schema.properties, :payload)
      assert prism.output_schema.required == ["action", "result"]
    end
  end
end
