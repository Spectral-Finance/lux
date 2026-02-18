defmodule Tests.TestLuxBeamsTwitterAnalyticsBeam do
  use ExUnit.Case

  alias Lux.Lenses.Twitter.GetTweetMetricsLens

  test "fetches tweet metrics successfully" do
    client = %Lux.Client{base_url: "https://api.twitter.com"}
    tweet_id = "1234567890"
    expected_metrics = %{
      retweet_count: 10,
      favorite_count: 5
    }

    # Mock the Client.get function to return a successful response
    allow(Client, :get, fn _client, url -> {:ok, Jason.encode!(expected_metrics)} end)

    assert {:ok, metrics} = GetTweetMetricsLens.fetch(client, tweet_id)
    assert metrics == expected_metrics
  end

  test "handles error when fetching tweet metrics" do
    client = %Lux.Client{base_url: "https://api.twitter.com"}
    tweet_id = "1234567890"

    # Mock the Client.get function to raise an error
    allow(Client, :get, fn _client, url -> {:error, %Error{message: "Invalid tweet ID"}} end)

    assert {:error, %Error{message: "Invalid tweet ID"}} = GetTweetMetricsLens.fetch(client, tweet_id)
  end
end