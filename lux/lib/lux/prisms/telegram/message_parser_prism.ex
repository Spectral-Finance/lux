defmodule Lux.Prisms.Telegram.MessageParserPrism do
  @moduledoc """
  Prism for parsing, normalizing, and analyzing Telegram messages using the Lux Python Telegram suite.
  """

  use Lux.Prism,
    name: "Telegram Message Parser Prism",
    description: "Extracts intent, sentiment, urgency, crypto entities, and metrics from incoming Telegram messages.",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "Raw message text to analyze"},
        update: %{type: :object, description: "Optional full Telegram update payload"}
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        intent: %{type: :string},
        confidence: %{type: :number},
        sentiment_score: %{type: :number},
        sentiment_label: %{type: :string},
        urgency: %{type: :string},
        urgency_score: %{type: :number},
        language: %{type: :string},
        is_spam: %{type: :boolean},
        is_toxic: %{type: :boolean},
        extracted_entities: %{type: :object},
        token_count: %{type: :integer},
        word_count: %{type: :integer}
      }
    }

  @impl true
  def handler(params, _agent) do
    text = params[:text] || params["text"] || ""

    result =
      python variables: %{text: text} do
        ~PY"""
        from lux.telegram.analysis import MessageAnalyzer
        analyzer = MessageAnalyzer()
        res = analyzer.analyze(text)
        {
            "intent": str(res.intent.value if hasattr(res.intent, 'value') else res.intent),
            "confidence": float(res.confidence),
            "sentiment_score": float(res.sentiment_score),
            "sentiment_label": str(res.sentiment_label),
            "urgency": str(res.urgency.value if hasattr(res.urgency, 'value') else res.urgency),
            "urgency_score": float(res.urgency_score),
            "language": str(res.language),
            "is_spam": bool(res.is_spam),
            "is_toxic": bool(res.is_toxic),
            "extracted_entities": res.extracted_entities,
            "token_count": int(res.token_count),
            "word_count": int(res.word_count)
        }
        """
      end

    {:ok, result}
  rescue
    e in RuntimeError ->
      {:error, "Message parsing failed: #{Exception.message(e)}"}
  end
end
