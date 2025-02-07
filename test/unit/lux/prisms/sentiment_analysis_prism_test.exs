defmodule Lux.Prisms.SentimentAnalysisPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.SentimentAnalysisPrism

  describe "handler/2" do
    test "analyzes positive sentiment correctly" do
      {:ok, result} =
        SentimentAnalysisPrism.run(%{
          text: "Great product, I love it! This is amazing.",
          language: "en"
        })

      assert result["sentiment"] == "positive"
      assert result["confidence"] > 0.5
      assert result["details"]["pos"] > result["details"]["neg"]
      assert result["details"]["compound"] > 0
    end

    test "analyzes negative sentiment correctly" do
      {:ok, result} =
        SentimentAnalysisPrism.run(%{
          text: "Terrible experience. I hate this product!",
          language: "en"
        })

      assert result["sentiment"] == "negative"
      assert result["confidence"] > 0.5
      assert result["details"]["neg"] > result["details"]["pos"]
      assert result["details"]["compound"] < 0
    end

    test "analyzes neutral sentiment correctly" do
      {:ok, result} =
        SentimentAnalysisPrism.run(%{
          text: "The product arrived today.",
          language: "en"
        })

      assert result["sentiment"] == "neutral"
      assert result["details"]["neu"] > result["details"]["pos"]
      assert result["details"]["neu"] > result["details"]["neg"]
      assert abs(result["details"]["compound"]) < 0.05
    end

    test "handles empty text gracefully" do
      {:ok, result} =
        SentimentAnalysisPrism.run(%{
          text: "",
          language: "en"
        })

      assert result["sentiment"] == "neutral"
      assert result["confidence"] == 0
      assert result["details"]["compound"] == 0
    end

    test "handles text with emojis" do
      {:ok, result} =
        SentimentAnalysisPrism.run(%{
          text: "Love this! 😍 Amazing product 🌟",
          language: "en"
        })

      assert result["sentiment"] == "positive"
      assert result["confidence"] > 0.5
      assert result["details"]["pos"] > result["details"]["neg"]
    end

    test "handles text with mixed sentiments" do
      {:ok, result} =
        SentimentAnalysisPrism.run(%{
          text: "The product is good but the service was terrible.",
          language: "en"
        })

      assert result["details"]["pos"] > 0
      assert result["details"]["neg"] > 0
    end

    test "defaults to English when no language is specified" do
      {:ok, result} =
        SentimentAnalysisPrism.run(%{
          text: "Great product!"
        })

      assert result["sentiment"] == "positive"
      assert result["confidence"] > 0
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SentimentAnalysisPrism.view()
      assert prism.input_schema.required == ["text"]
      assert Map.has_key?(prism.input_schema.properties, :text)
      assert Map.has_key?(prism.input_schema.properties, :language)
    end

    test "validates output schema" do
      prism = SentimentAnalysisPrism.view()
      assert prism.output_schema.required == ["sentiment", "confidence", "details"]
      assert Map.has_key?(prism.output_schema.properties, :sentiment)
      assert Map.has_key?(prism.output_schema.properties, :confidence)
      assert Map.has_key?(prism.output_schema.properties, :details)
    end
  end
end
