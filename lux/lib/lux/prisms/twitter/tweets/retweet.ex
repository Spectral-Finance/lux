defmodule Lux.Prisms.Twitter.Tweets.Retweet do
  @moduledoc """
  Prism for retweeting/unretweeting via Twitter API v2.
  """

  use Lux.Prism,
    name: "Retweet",
    description: "Retweets or undoes a retweet",
    input_schema: %{
      type: :object,
      properties: %{
        tweet_id: %{type: :string, description: "Tweet ID to retweet"},
        user_id: %{type: :string, description: "Authenticated user's ID"},
        undo: %{type: :boolean, description: "If true, undo retweet", default: false}
      },
      required: ["tweet_id", "user_id"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(%{"tweet_id" => tweet_id, "user_id" => user_id} = params, _context) do
    if params["undo"] do
      case Client.request(:delete, "/users/#{user_id}/retweets/#{tweet_id}", %{auth_type: :oauth1}) do
        {:ok, _} -> {:ok, %{retweeted: false, tweet_id: tweet_id}}
        {:error, reason} -> {:error, "Failed to undo retweet: #{inspect(reason)}"}
      end
    else
      case Client.request(:post, "/users/#{user_id}/retweets", %{
             auth_type: :oauth1,
             json: %{"tweet_id" => tweet_id}
           }) do
        {:ok, _} -> {:ok, %{retweeted: true, tweet_id: tweet_id}}
        {:error, reason} -> {:error, "Failed to retweet: #{inspect(reason)}"}
      end
    end
  end
end
