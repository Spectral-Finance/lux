defmodule Lux.Integrations.Twitter.Scheduler do
  @moduledoc """
  Module for scheduling tweets on Twitter.
  """

  import Lux.Integrations.Twitter.Client
  import HTTPoison

  def schedule_tweet(tweet, time) do
    Client.post("/1.1/statuses/update.json", %{
      status: tweet,
      auto_populate_reply_metadata: true,
      display_coordinates: true,
      trim_user: true
    }, headers: [{"Authorization", "Bearer YOUR_TWITTER_BEARER_TOKEN"}])
  end
end

def init(_) do
  {:ok, %{}}
end