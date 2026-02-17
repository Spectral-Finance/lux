defmodule Lux.Test.Integrations.TwitterTest do
  use ExUnit.Case
  import HTTPoison
  alias Lux.Twitter

  test "posts a tweet" do
    response = Twitter.post_tweet("Hello, world!")
    assert response.status_code == 201
  end

  test "fetches user timeline" do
    response = Twitter.fetch_user_timeline("twitter_handle")
    assert response.status_code == 200
  end
end

def setup do
  {:ok, client} = HTTPoison.start()
  {:ok, %{client: client}}
end