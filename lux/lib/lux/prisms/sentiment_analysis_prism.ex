defmodule Lux.Prisms.SentimentAnalysisPrism do
  @moduledoc """
  A prism that performs sentiment analysis on text using Python's NLTK library.

  This prism uses NLTK's VADER (Valence Aware Dictionary and sEntiment Reasoner) sentiment analyzer,
  which is specifically attuned to sentiments expressed in social media. It's able to handle:

  - Conventional text
  - Slang and abbreviations
  - Emojis and emoticons
  - Emphasis through capitalization and punctuation

  ## Examples

      iex> Lux.Prisms.SentimentAnalysisPrism.run(%{
      ...>   text: "Great product, I love it!",
      ...>   language: "en"
      ...> })
      {:ok, %{
        sentiment: "positive",
        confidence: 0.8402,
        details: %{
          "pos" => 0.814,
          "neg" => 0.0,
          "neu" => 0.186,
          "compound" => 0.8402
        }
      }}
  """

  use Lux.Prism,
    name: "Sentiment Analysis",
    description: "Analyzes text sentiment using NLTK's VADER sentiment analyzer",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{
          type: :string,
          description: "Text to analyze for sentiment"
        },
        language: %{
          type: :string,
          description: "ISO language code (currently only 'en' is fully supported)",
          enum: ["en"]
        }
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sentiment: %{
          type: :string,
          enum: ["positive", "negative", "neutral"],
          description: "Overall sentiment classification"
        },
        confidence: %{
          type: :number,
          minimum: 0,
          maximum: 1,
          description: "Confidence score for the sentiment classification"
        },
        details: %{
          type: :object,
          description: "Detailed sentiment scores",
          properties: %{
            "pos" => %{type: :number, description: "Positive sentiment score"},
            "neg" => %{type: :number, description: "Negative sentiment score"},
            "neu" => %{type: :number, description: "Neutral sentiment score"},
            "compound" => %{type: :number, description: "Compound sentiment score"}
          }
        }
      },
      required: ["sentiment", "confidence", "details"]
    }

  import Lux.Python

  require Lux.Python

  @doc """
  Analyzes the sentiment of the given text.

  ## Parameters

    * `text` - The text to analyze
    * `language` - The language of the text (currently only "en" is supported)

  ## Returns

    * `{:ok, result}` - Where result contains sentiment analysis
    * `{:error, reason}` - If analysis fails
  """
  def handler(%{text: text} = input, _ctx) do
    with {:ok, %{"success" => true}} <- Lux.Python.import_package("nltk"),
         language = Map.get(input, :language, "en"),
         {:ok, result} <- analyze_sentiment(text, language) do
      {:ok, result}
    else
      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import NLTK: #{error}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp analyze_sentiment(text, language) do
    result =
      python variables: %{text: text, language: language} do
        ~PY"""
        import nltk
        from nltk.sentiment import SentimentIntensityAnalyzer

        # Ensure VADER lexicon is available
        try:
            nltk.data.find('vader_lexicon')
        except LookupError:
            nltk.download('vader_lexicon', quiet=True)

        # Initialize the VADER sentiment analyzer
        sia = SentimentIntensityAnalyzer()

        # Get the sentiment scores
        scores = sia.polarity_scores(text)

        # Determine overall sentiment
        compound = scores['compound']
        if compound >= 0.05:
            sentiment = "positive"
        elif compound <= -0.05:
            sentiment = "negative"
        else:
            sentiment = "neutral"

        # Format the response
        {
            "sentiment": sentiment,
            "confidence": abs(compound),
            "details": {
                "pos": scores["pos"],
                "neg": scores["neg"],
                "neu": scores["neu"],
                "compound": scores["compound"]
            }
        }
        """
      end

    {:ok, result}
  rescue
    e in RuntimeError ->
      {:error, "Sentiment analysis failed: #{Exception.message(e)}"}
  end
end
