defmodule Lux.Prisms.Twitter.Analytics.AnalyzeSentimentTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Twitter.Analytics.AnalyzeSentiment

  @agent_ctx %{name: "TestAgent"}

  describe "handler/2 — sentiment analysis" do
    test "classifies positive text" do
      assert {:ok, result} = AnalyzeSentiment.handler(%{text: "This is amazing and wonderful!"}, @agent_ctx)
      assert result.overall == "positive"
      assert result.score > 0
    end

    test "classifies negative text" do
      assert {:ok, result} = AnalyzeSentiment.handler(%{text: "This is terrible and awful and horrible"}, @agent_ctx)
      assert result.overall == "negative"
      assert result.score < 0
    end

    test "classifies neutral text" do
      assert {:ok, result} = AnalyzeSentiment.handler(%{text: "The meeting is at 3pm"}, @agent_ctx)
      assert result.overall == "neutral"
    end

    test "analyzes multiple texts with breakdown" do
      assert {:ok, result} = AnalyzeSentiment.handler(%{
        texts: ["Great work!", "I love this!", "Terrible experience"]
      }, @agent_ctx)
      assert result.breakdown.positive == 2
      assert result.breakdown.negative == 1
      assert result.breakdown.neutral == 0
      assert result.overall == "positive"
      assert length(result.classified) == 3
    end

    test "returns error without text or texts" do
      assert {:error, msg} = AnalyzeSentiment.handler(%{}, @agent_ctx)
      assert msg =~ "required"
    end

    test "accepts string keys" do
      assert {:ok, result} = AnalyzeSentiment.handler(%{"text" => "Great amazing work!"}, @agent_ctx)
      assert result.overall == "positive"
    end

    test "handles empty text as neutral" do
      assert {:ok, result} = AnalyzeSentiment.handler(%{text: ""}, @agent_ctx)
      assert result.overall == "neutral"
    end

    test "aggregate score ranges from -1 to 1" do
      assert {:ok, result} = AnalyzeSentiment.handler(%{texts: ["good", "bad", "neutral"]}, @agent_ctx)
      assert result.score >= -1.0
      assert result.score <= 1.0
    end
  end
end
