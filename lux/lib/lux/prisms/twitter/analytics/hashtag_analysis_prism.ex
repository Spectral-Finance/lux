defmodule Lux.Prisms.Twitter.Analytics.HashtagAnalysisPrism do
  @moduledoc """
  A prism that analyzes hashtag reach, engagement, and frequency across tweets.
  """

  use Lux.Prism,
    name: "Twitter Hashtag Analysis Prism",
    description: "Evaluates hashtag occurrences, impressions, and engagement volume",
    input_schema: %{
      type: :object,
      properties: %{
        tweets: %{
          type: :array,
          description: "List of tweet objects containing hashtag lists and impressions"
        }
      },
      required: ["tweets"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        hashtags_count: %{type: :integer},
        hashtag_stats: %{type: :object},
        success: %{type: :boolean}
      },
      required: ["hashtags_count", "hashtag_stats", "success"]
    }

  alias Lux.Twitter.Analytics.Aggregator

  @impl true
  def handler(inputs, _context) do
    tweets = Map.get(inputs, "tweets") || Map.get(inputs, :tweets, [])

    stats = Aggregator.analyze_hashtags(tweets)

    {:ok,
     %{
       hashtags_count: map_size(stats),
       hashtag_stats: stats,
       success: true
     }}
  end
end
