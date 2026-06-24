defmodule Lux.Lenses.Twitter.SearchRecentTweetsLensTest do
  use ExUnit.Case, async: false

  import Mock
  alias Lux.Lenses.Twitter.SearchRecentTweetsLens

  setup do
    Application.put_env(:lux, :api_keys, [
      twitter_bearer_token: "TEST_BEARER_TOKEN"
    ])
    :ok
  end

  describe "focus/2" do
    test "searches recent tweets successfully" do
      with_mock Req, [get: fn(_client, opts) ->
        assert opts[:url] == "/tweets/search/recent"
        assert opts[:params][:query] == "#lux"
        {:ok, %Req.Response{status: 200, body: %{
          "data" => [
            %{"id" => "1", "text" => "Lux is great!"}
          ]
        }}}
      end] do
        assert {:ok, tweets} = SearchRecentTweetsLens.focus(%{"query" => "#lux"}, %{})
        assert length(tweets) == 1
        assert hd(tweets)["id"] == "1"
      end
    end

    test "handles empty search results" do
      with_mock Req, [get: fn(_client, opts) ->
        assert opts[:url] == "/tweets/search/recent"
        {:ok, %Req.Response{status: 200, body: %{
          "meta" => %{"result_count" => 0}
        }}}
      end] do
        assert {:ok, []} = SearchRecentTweetsLens.focus(%{"query" => "#lux"}, %{})
      end
    end

    test "handles errors" do
      with_mock Req, [get: fn(_client, _opts) ->
        {:ok, %Req.Response{status: 400, body: %{"errors" => ["bad query"]}}}
      end] do
        assert {:error, "Twitter API error (status 400): %{\"errors\" => [\"bad query\"]}"} = SearchRecentTweetsLens.focus(%{"query" => ""}, %{})
      end
    end
  end
end
