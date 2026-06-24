defmodule Lux.Lenses.Twitter.GetTweetMetricsLensTest do
  use ExUnit.Case, async: false

  import Mock
  alias Lux.Lenses.Twitter.GetTweetMetricsLens

  setup do
    Application.put_env(:lux, :api_keys, [
      twitter_bearer_token: "TEST_BEARER_TOKEN"
    ])
    :ok
  end

  describe "focus/2" do
    test "fetches metrics successfully" do
      with_mock Req, [get: fn(_client, opts) ->
        assert opts[:url] == "/tweets/12345"
        {:ok, %Req.Response{status: 200, body: %{
          "data" => %{
            "public_metrics" => %{
              "retweet_count" => 10,
              "reply_count" => 5,
              "like_count" => 100,
              "quote_count" => 2
            }
          }
        }}}
      end] do
        assert {:ok, metrics} = GetTweetMetricsLens.focus(%{"tweet_id" => "12345"}, %{})
        assert metrics["like_count"] == 100
      end
    end

    test "handles errors" do
      with_mock Req, [get: fn(_client, _opts) ->
        {:error, :nxdomain}
      end] do
        assert {:error, "Request failed: :nxdomain"} = GetTweetMetricsLens.focus(%{"tweet_id" => "12345"}, %{})
      end
    end
  end
end
