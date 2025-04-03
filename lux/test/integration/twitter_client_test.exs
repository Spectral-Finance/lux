defmodule Lux.Integration.Twitter.ClientTest do
  use IntegrationCase, async: true

  alias Lux.Integrations.Twitter.Client

  describe "basic Twitter API integration" do
    setup do
      config = %{
        api_key: Application.get_env(:lux, :api_keys)[:integration_twitter]
      }

      # Skip tests if no Twitter API key is configured
      if is_nil(config.api_key) do
        skip_test = "No Twitter API key configured"
        {:skip, skip_test}
      else
        %{config: config}
      end
    end

    test "can fetch a tweet by ID", %{config: _config} do
      # Use a well-known tweet ID that is unlikely to be deleted
      # This is Twitter's own "Hello World" tweet
      tweet_id = "1460323737035677698"

      assert {:ok, response} = Client.request(:get, "/tweets/#{tweet_id}", %{
        "tweet.fields": "author_id,created_at,public_metrics"
      })

      assert %{"data" => tweet_data} = response
      assert tweet_data["id"] == tweet_id
      assert Map.has_key?(tweet_data, "text")
      assert Map.has_key?(tweet_data, "author_id")
      assert Map.has_key?(tweet_data, "created_at")
    end

    test "can fetch user information by username", %{config: _config} do
      # Use Twitter's official account
      username = "Twitter"

      assert {:ok, response} = Client.request(:get, "/users/by/username/#{username}")

      assert %{"data" => user_data} = response
      assert user_data["username"] == username
      assert Map.has_key?(user_data, "id")
      assert Map.has_key?(user_data, "name")
    end

    test "handles error responses appropriately", %{config: _config} do
      # Use a non-existent tweet ID
      tweet_id = "999999999999999999999"

      assert {:error, {404, _}} = Client.request(:get, "/tweets/#{tweet_id}")
    end

    test "can search recent tweets", %{config: _config} do
      # Search for tweets about Elixir programming language
      query = "elixir lang"

      assert {:ok, response} = Client.request(:get, "/tweets/search/recent", %{
        query: query,
        "tweet.fields": "created_at"
      })

      assert %{"meta" => meta} = response
      assert Map.has_key?(meta, "result_count")

      # Even if no tweets are found, the structure should be correct
      if meta["result_count"] > 0 do
        assert %{"data" => tweets} = response
        assert is_list(tweets)
        assert Map.has_key?(hd(tweets), "id")
        assert Map.has_key?(hd(tweets), "text")
      end
    end
  end
end
