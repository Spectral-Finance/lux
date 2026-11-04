defmodule Lux.Prisms.Twitter.Analytics.SentimentAnalysisPrism do
  @moduledoc """
  A prism that analyzes the sentiment and polarity of Twitter mentions and discussions.
  """

  use Lux.Prism,
    name: "Twitter Sentiment Analysis Prism",
    description: "Evaluates sentiment, polarity score, and classification of Twitter mentions",
    input_schema: %{
      type: :object,
      properties: %{
        mentions: %{
          type: :array,
          items: %{type: :string},
          description: "List of mention texts to evaluate"
        }
      },
      required: ["mentions"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        total_analyzed: %{type: :integer},
        average_polarity: %{type: :number},
        positive_ratio: %{type: :number},
        negative_ratio: %{type: :number},
        sentiment_summary: %{type: :object}
      },
      required: ["total_analyzed", "average_polarity"]
    }

  alias Lux.Twitter.Analytics.Sentiment

  @impl true
  def handler(inputs, _context) do
    mentions = Map.get(inputs, "mentions") || Map.get(inputs, :mentions, [])

    stats = Sentiment.aggregate_sentiment(mentions)

    {:ok,
     %{
       total_analyzed: stats.total_analyzed,
       average_polarity: stats.average_polarity,
       positive_ratio: stats.positive_ratio,
       negative_ratio: stats.negative_ratio,
       sentiment_summary: stats
     }}
  end
end
