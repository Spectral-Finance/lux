defmodule Lux.Integrations.Twitter.Prism do
  @moduledoc """
  Twitter engagement engine prism for Lux.
  """

  alias Lux.Config

  def engage(user_id, tweet_id) do
    config = Config.get(:twitter)
    access_token = config.access_token

    url = "https://api.twitter.com/1.1/statuses/update.json"
    params = [
      status: "Engaging with tweet #{tweet_id}",
      in_reply_to_status_id: tweet_id
    ]

    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/x-www-form-urlencoded"}
    ]

    response = HTTPoison.post(url, URI.encode_query(params), headers)

    case response do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        {:ok, "Engagement successful"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end
end

def evaluate_keyword_matches(user_id, tweet_id, keywords) do
  config = Config.get(:twitter)
  access_token = config.access_token

  url = "https://api.twitter.com/1.1/statuses/show.json"
  params = [
    id: tweet_id
  ]

  headers = [
    {"Authorization", "Bearer #{access_token}"},
    {"Content-Type", "application/x-www-form-urlencoded"}
  ]

  response = HTTPoison.get(url, headers, query: params)

  case response do
    {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
      tweet_text = Jason.decode!(body)["text"]
      keyword_matches = Enum.filter(keywords, fn keyword -> String.contains?(String.downcase(tweet_text), String.downcase(keyword)) end)
      {:ok, keyword_matches}

    {:error, %HTTPoison.Error{reason: reason}} ->
      {:error, reason}
  end
end