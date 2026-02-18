# Lines 1-34 of lux/test/lux/lenses/twitter/get_tweet_metrics_lens_test.exs
defmodule Lux.Lenses.Twitter.GetTweetMetricsLensTest do
  use ExUnit.Case, async: true

  import ExUnit.Assertions
  alias Lux.{Client, Error}
  alias Lux.Lenses.Twitter.GetTweetMetricsLens

  test "fetches tweet metrics successfully" do
    client = %Client{base_url: "https://api.twitter.com"}
    tweet_id = "1234567890"

    mock_response = %{
      "retweet_count" => 10,
      "favorite_count" => 5
    }

    expect(Client, :get, fn _, url -> {:ok, mock_response} end)

    assert {:ok, metrics} = GetTweetMetricsLens.fetch(client, tweet_id)
    assert metrics == %{
             retweet_count: 10,
             favorite_count: 5
           }
  end

  test "returns error when fetching tweet metrics fails" do
    client = %Client{base_url: "https://api.twitter.com"}
    tweet_id = "1234567890"

    expect(Client, :get, fn _, _ -> {:error, Error.new("Request failed")} end)

    assert {:error, error} = GetTweetMetricsLens.fetch(client, tweet_id)
    assert %Error{message: "Request failed"} = error
  end
end
