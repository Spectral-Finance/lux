defmodule Lux.Lenses.Twitter.GetUserMetricsLensTest do
  use ExUnit.Case, async: false

  import Mock
  alias Lux.Lenses.Twitter.GetUserMetricsLens

  setup do
    Application.put_env(:lux, :api_keys, [
      twitter_bearer_token: "TEST_BEARER_TOKEN"
    ])
    :ok
  end

  describe "focus/2" do
    test "fetches user metrics successfully" do
      with_mock Req, [get: fn(_client, opts) ->
        assert opts[:url] == "/users/by/username/spectrallabs"
        {:ok, %Req.Response{status: 200, body: %{
          "data" => %{
            "public_metrics" => %{
              "followers_count" => 10000,
              "following_count" => 500,
              "tweet_count" => 1200
            }
          }
        }}}
      end] do
        assert {:ok, metrics} = GetUserMetricsLens.focus(%{"username" => "spectrallabs"}, %{})
        assert metrics["followers_count"] == 10000
      end
    end

    test "handles errors" do
      with_mock Req, [get: fn(_client, _opts) ->
        {:ok, %Req.Response{status: 404, body: %{"errors" => ["Not Found"]}}}
      end] do
        assert {:error, "Twitter API error (status 404): %{\"errors\" => [\"Not Found\"]}"} = GetUserMetricsLens.focus(%{"username" => "unknown"}, %{})
      end
    end
  end
end
