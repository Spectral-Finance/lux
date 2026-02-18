defmodule Lux.Beams.Twitter.AnalyticsBeamTest do
  # Lines 2-5 of lux/test/lux/beams/twitter/analytics_beam_test.exs
  use ExUnit.Case, async: true

  import ExUnit.Assertions

  alias Lux.Lenses.Twitter.GetTweetMetricsLens
    tweet_id = "1234567890"

    response = %{
      "retweet_count" => 10,
      "favorite_count" => 5
    }

    Client = struct(Lux.Client, base_url: "https://api.twitter.com")
    expect(Client, :get, fn _, _ -> {:ok, response} end)

    assert {:ok, metrics} = GetTweetMetricsLens.fetch(client, tweet_id)
    assert metrics == %{
      retweet_count: 10,
      favorite_count: 5
    }
  end
end