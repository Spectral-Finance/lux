defmodule Lux.Prisms.Twitter.Tweets.LikeTweet do
  @moduledoc """
  Prism for liking/unliking tweets via Twitter API v2.
  """

  use Lux.Prism,
    name: "Like Tweet",
    description: "Likes or unlikes a tweet",
    input_schema: %{
      type: :object,
      properties: %{
        tweet_id: %{type: :string, description: "Tweet ID to like/unlike"},
        user_id: %{type: :string, description: "Authenticated user's ID"},
        unlike: %{type: :boolean, description: "If true, unlike instead of like", default: false}
      },
      required: ["tweet_id", "user_id"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(%{"tweet_id" => tweet_id, "user_id" => user_id} = params, _context) do
    if params["unlike"] do
      case Client.request(:delete, "/users/#{user_id}/likes/#{tweet_id}", %{auth_type: :oauth1}) do
        {:ok, _} -> {:ok, %{liked: false, tweet_id: tweet_id}}
        {:error, reason} -> {:error, "Failed to unlike: #{inspect(reason)}"}
      end
    else
      case Client.request(:post, "/users/#{user_id}/likes", %{
             auth_type: :oauth1,
             json: %{"tweet_id" => tweet_id}
           }) do
        {:ok, _} -> {:ok, %{liked: true, tweet_id: tweet_id}}
        {:error, reason} -> {:error, "Failed to like: #{inspect(reason)}"}
      end
    end
  end
end
