# Lines 1-32 of lux/test/lux/prisms/twitter/analyze_engagement_prism_test.exs
defmodule Lux.Prisms.Twitter.AnalyzeEngagementPrismTest do
  use ExUnit.Case, async: true

  import ExUnit.Assertions
  alias Lux.Lenses.Twitter.GetTweetMetricsLens

  test "fetches tweet metrics" do
    client = %Lux.Client{base_url: "https://api.twitter.com"}
    tweet_id = "1234567890"

    response = %{
      "retweet_count" => 10,
      "favorite_count" => 20
    }

    Client = struct(Client, get: fn _, _ -> {:ok, response} end)

    assert {:ok, metrics} = GetTweetMetricsLens.fetch(client, tweet_id)
    assert metrics == %{
             retweet_count: 10,
             favorite_count: 20
           }
  end

  test "handles errors" do
    client = %Lux.Client{base_url: "https://api.twitter.com"}
    tweet_id = "1234567890"

    Client = struct(Client, get: fn _, _ -> {:error, :not_found} end)

    assert {:error, _} = GetTweetMetricsLens.fetch(client, tweet_id)
  end
end
