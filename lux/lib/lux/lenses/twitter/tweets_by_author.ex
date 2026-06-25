defmodule Lux.Lenses.Twitter.TweetsByAuthor do
  @moduledoc """
  Lens for fetching tweets by author (user) from Twitter API v2.

  ## Examples

      iex> Lux.Lenses.Twitter.TweetsByAuthor.focus(%{user_id: "123456"})
      {:ok, %{tweets: [%{id: "789", text: "Hello"}]}}
  """

  use Lux.Lens,
    name: "Twitter.TweetsByAuthor",
    description: "Fetches recent tweets authored by a specific Twitter user",
    url: "https://api.twitter.com/2/users/:user_id/tweets",
    method: :get,
    auth: %{
      type: :custom,
      auth_function: &Lux.Integrations.Twitter.add_auth_header/1
    },
    schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :string,
          description: "The Twitter user ID to fetch tweets for"
        },
        max_results: %{
          type: :integer,
          description: "Number of tweets to return (10-100)",
          default: 10,
          minimum: 10,
          maximum: 100
        },
        tweet.fields: %{
          type: :string,
          description: "Comma-separated list of tweet fields to include"
        },
        expansions: %{
          type: :string,
          description: "Comma-separated list of field expansions"
        },
        media.fields: %{
          type: :string,
          description: "Comma-separated list of media fields"
        },
        place.fields: %{
          type: :string,
          description: "Comma-separated list of place fields"
        },
        poll.fields: %{
          type: :string,
          description: "Comma-separated list of poll fields"
        },
        author_fields: %{
          type: :string,
          description: "Comma-separated list of author fields"
        }
      },
      required: ["user_id"]
    }

  def after_focus(%{"data" => tweets}) do
    {:ok, %{
      tweets: tweets,
      count: length(tweets),
      meta: Map.get(tweets_meta(tweets), "meta", %{})
    }}
  end

  def after_focus(%{"errors" => errors}) do
    {:error, List.first(errors)["message"]}
  end

  def after_focus(body), do: {:ok, body}

  defp tweets_meta(tweets) do
    Enum.find(tweets, %{}, &Map.has_key?(&1, "__meta__"))
    |> Map.get("__meta__", %{})
  end
end
