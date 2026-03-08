defmodule Lux.Prisms.Twitter.Tweets.Bookmark do
  @moduledoc """
  Prism for bookmarking/unbookmarking tweets via Twitter API v2.
  """

  use Lux.Prism,
    name: "Bookmark Tweet",
    description: "Bookmarks or removes a bookmark from a tweet",
    input_schema: %{
      type: :object,
      properties: %{
        tweet_id: %{type: :string, description: "Tweet ID to bookmark"},
        user_id: %{type: :string, description: "Authenticated user's ID"},
        remove: %{type: :boolean, description: "If true, remove bookmark", default: false}
      },
      required: ["tweet_id", "user_id"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(%{"tweet_id" => tweet_id, "user_id" => user_id} = params, _context) do
    if params["remove"] do
      case Client.request(:delete, "/users/#{user_id}/bookmarks/#{tweet_id}", %{auth_type: :oauth1}) do
        {:ok, _} -> {:ok, %{bookmarked: false, tweet_id: tweet_id}}
        {:error, reason} -> {:error, "Failed to remove bookmark: #{inspect(reason)}"}
      end
    else
      case Client.request(:post, "/users/#{user_id}/bookmarks", %{
             auth_type: :oauth1,
             json: %{"tweet_id" => tweet_id}
           }) do
        {:ok, _} -> {:ok, %{bookmarked: true, tweet_id: tweet_id}}
        {:error, reason} -> {:error, "Failed to bookmark: #{inspect(reason)}"}
      end
    end
  end
end
