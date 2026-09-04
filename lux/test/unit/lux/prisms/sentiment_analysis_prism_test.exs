defmodule Lux.Prisms.SentimentAnalysisPrismTest do
  use UnitCase, async: false
  import Mock

  alias Lux.Prisms.SentimentAnalysisPrism

  defp mock_sentiment(text) do
    cond do
      text == "" ->
        %{
          "sentiment" => "neutral",
          "confidence" => 0.0,
          "details" => %{"pos" => 0.0, "neg" => 0.0, "neu" => 1.0, "compound" => 0.0}
        }

      String.contains?(text, "Terrible") or String.contains?(text, "hate") ->
        %{
          "sentiment" => "negative",
          "confidence" => 0.78,
          "details" => %{"pos" => 0.0, "neg" => 0.78, "neu" => 0.22, "compound" => -0.78}
        }

      String.contains?(text, "arrived") ->
        %{
          "sentiment" => "neutral",
          "confidence" => 0.0,
          "details" => %{"pos" => 0.0, "neg" => 0.0, "neu" => 1.0, "compound" => 0.0}
        }

      String.contains?(text, "good but") ->
        %{
          "sentiment" => "neutral",
          "confidence" => 0.0,
          "details" => %{"pos" => 0.4, "neg" => 0.35, "neu" => 0.25, "compound" => 0.02}
        }

      true ->
        %{
          "sentiment" => "positive",
          "confidence" => 0.84,
          "details" => %{"pos" => 0.81, "neg" => 0.0, "neu" => 0.19, "compound" => 0.84}
        }
    end
  end

  defp with_nltk_mock(fun) do
    case Lux.Python.import_package("nltk") do
      {:ok, %{"success" => true}} ->
        fun.()

      _ ->
        with_mock Lux.Python, [:passthrough], [
          import_package: fn "nltk" -> {:ok, %{"success" => true}} end,
          eval!: fn _code, opts ->
            text = get_in(opts, [:variables, :text]) || ""
            mock_sentiment(text)
          end
        ] do
          fun.()
        end
    end
  end

  describe "handler/2" do
    test "analyzes positive sentiment correctly" do
      with_nltk_mock(fn ->
        {:ok, result} =
          SentimentAnalysisPrism.run(%{
            text: "Great product, I love it! This is amazing.",
            language: "en"
          })

        assert result["sentiment"] == "positive"
        assert result["confidence"] > 0.5
        assert result["details"]["pos"] > result["details"]["neg"]
        assert result["details"]["compound"] > 0
      end)
    end

    test "analyzes negative sentiment correctly" do
      with_nltk_mock(fn ->
        {:ok, result} =
          SentimentAnalysisPrism.run(%{
            text: "Terrible experience. I hate this product!",
            language: "en"
          })

        assert result["sentiment"] == "negative"
        assert result["confidence"] > 0.5
        assert result["details"]["neg"] > result["details"]["pos"]
        assert result["details"]["compound"] < 0
      end)
    end

    test "analyzes neutral sentiment correctly" do
      with_nltk_mock(fn ->
        {:ok, result} =
          SentimentAnalysisPrism.run(%{
            text: "The product arrived today.",
            language: "en"
          })

        assert result["sentiment"] == "neutral"
        assert result["details"]["neu"] > result["details"]["pos"]
        assert result["details"]["neu"] > result["details"]["neg"]
        assert abs(result["details"]["compound"]) < 0.05
      end)
    end

    test "handles empty text gracefully" do
      with_nltk_mock(fn ->
        {:ok, result} =
          SentimentAnalysisPrism.run(%{
            text: "",
            language: "en"
          })

        assert result["sentiment"] == "neutral"
        assert result["confidence"] == 0
        assert result["details"]["compound"] == 0
      end)
    end

    test "handles text with emojis" do
      with_nltk_mock(fn ->
        {:ok, result} =
          SentimentAnalysisPrism.run(%{
            text: "Love this! 😍 Amazing product 🌟",
            language: "en"
          })

        assert result["sentiment"] == "positive"
        assert result["confidence"] > 0.5
        assert result["details"]["pos"] > result["details"]["neg"]
      end)
    end

    test "handles text with mixed sentiments" do
      with_nltk_mock(fn ->
        {:ok, result} =
          SentimentAnalysisPrism.run(%{
            text: "The product is good but the service was terrible.",
            language: "en"
          })

        assert result["details"]["pos"] > 0
        assert result["details"]["neg"] > 0
      end)
    end

    test "defaults to English when no language is specified" do
      with_nltk_mock(fn ->
        {:ok, result} =
          SentimentAnalysisPrism.run(%{
            text: "Great product!"
          })

        assert result["sentiment"] == "positive"
        assert result["confidence"] > 0
      end)
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
