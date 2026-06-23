defmodule Lux.Prisms.Twitter.CreateTweetPrism do
  @moduledoc """
  Prism for creating a tweet.
  """
  use Lux.Prism,
    name: "Create Tweet",
    description: "Sends a POST request to create a tweet",
    input_schema: %{
      type: :object,
      properties: %{
        token: %{type: :string, description: "OAuth 2.0 Bearer token"},
        text: %{type: :string, description: "The text of the tweet"},
        quote_tweet_id: %{type: :string, description: "ID of the tweet to quote"},
        media_ids: %{type: :array, items: %{type: :string}, description: "List of media IDs"}
      },
      required: ["token", "text"]
    }

  def handler(input, _ctx \\ nil) do
    token = input[:token] || input["token"]

    payload = %{
      text: input[:text] || input["text"]
    }

    quote_id = input[:quote_tweet_id] || input["quote_tweet_id"]
    payload = if quote_id, do: Map.put(payload, :quote_tweet_id, quote_id), else: payload

    media_ids = input[:media_ids] || input["media_ids"]
    payload = if media_ids, do: Map.put(payload, :media, %{media_ids: media_ids}), else: payload

    url = "https://api.twitter.com/2/tweets"

    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]

    case Req.post(url, json: payload, headers: headers) do
      {:ok, %Req.Response{status: 201, body: %{"data" => data}, headers: response_headers}} ->
        remaining = get_header(response_headers, "x-rate-limit-remaining")
        {:ok, %{
          id: data["id"],
          text: data["text"],
          rate_limit_remaining: remaining
        }}
      {:ok, %Req.Response{status: 429, headers: response_headers}} ->
        retry_after = get_header(response_headers, "x-rate-limit-reset")
        {:error, %{reason: :rate_limit, retry_after: retry_after}}
      {:ok, response} ->
        {:error, response.body}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_header(headers, key) do
    case Enum.find(headers, fn {k, _v} -> String.downcase(k) == key end) do
      {^key, value} -> value
      _ -> nil
    end
  end
end
