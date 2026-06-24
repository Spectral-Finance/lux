defmodule Lux.Lenses.Twitter.GetTweetMetricsLens do
  @moduledoc """
  Lens to fetch engagement metrics for a specific tweet.
  """
  use Lux.Lens

  alias Lux.Lenses.Twitter.Base, as: TwitterBase

  @impl true
  def name, do: "Twitter Get Tweet Metrics Lens"

  @impl true
  def description, do: "Fetches engagement metrics (retweets, replies, likes, quotes) for a given tweet ID."

  @impl true
  def schema do
    %{
      type: :object,
      properties: %{
        tweet_id: %{
          type: :string,
          description: "The ID of the tweet to fetch metrics for."
        }
      },
      required: ["tweet_id"]
    }
  end

  @impl true
  def focus(%{"tweet_id" => tweet_id}, _context) do
    client = TwitterBase.client()

    Req.get(client, url: "/tweets/#{tweet_id}", params: [
      "tweet.fields": "public_metrics"
    ])
    |> TwitterBase.process_response()
    |> case do
      {:ok, %{"data" => %{"public_metrics" => metrics}}} ->
        {:ok, metrics}
      {:ok, other} ->
        {:error, "Unexpected response format: #{inspect(other)}"}
      {:error, reason} ->
        {:error, reason}
    end
  end
end
