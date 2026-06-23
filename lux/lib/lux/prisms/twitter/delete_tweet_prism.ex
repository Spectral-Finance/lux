defmodule Lux.Prisms.Twitter.DeleteTweetPrism do
  @moduledoc """
  Prism for deleting a tweet.
  """
  use Lux.Prism,
    name: "Delete Tweet",
    description: "Sends a DELETE request to delete a tweet by its ID",
    input_schema: %{
      type: :object,
      properties: %{
        token: %{type: :string, description: "OAuth 2.0 Bearer token"},
        tweet_id: %{type: :string, description: "The ID of the tweet to delete"}
      },
      required: ["token", "tweet_id"]
    }

  def handler(input, _ctx \\ nil) do
    token = input[:token] || input["token"]
    tweet_id = input[:tweet_id] || input["tweet_id"]

    url = "https://api.twitter.com/2/tweets/#{tweet_id}"

    headers = [
      {"Authorization", "Bearer #{token}"}
    ]

    case Req.delete(url, headers: headers) do
      {:ok, %Req.Response{status: 200, body: %{"data" => %{"deleted" => true}}}} ->
        {:ok, %{deleted: true}}
      {:ok, response} ->
        {:error, response.body}
      {:error, reason} ->
        {:error, reason}
    end
  end
end
