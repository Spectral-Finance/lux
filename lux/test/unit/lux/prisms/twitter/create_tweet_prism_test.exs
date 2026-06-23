defmodule Lux.Prisms.Twitter.CreateTweetPrismTest do
  use ExUnit.Case, async: false
  import Mock
  alias Lux.Prisms.Twitter.CreateTweetPrism

  describe "CreateTweetPrism" do
    test "successfully creates a tweet" do
      input = %{
        "token" => "test_token",
        "text" => "Hello World"
      }

      response_body = %{
        "data" => %{
          "id" => "12345",
          "text" => "Hello World"
        }
      }

      with_mock Req, [post: fn _url, opts -> 
        assert opts[:json][:text] == "Hello World"
        assert Enum.member?(opts[:headers], {"Authorization", "Bearer test_token"})
        headers = [{"x-rate-limit-remaining", "99"}]
        {:ok, %Req.Response{status: 201, body: response_body, headers: headers}}
      end] do
        assert {:ok, %{id: "12345", text: "Hello World", rate_limit_remaining: "99"}} = CreateTweetPrism.handler(input)
      end
    end

    test "handles rate limit correctly" do
      input = %{
        "token" => "test_token",
        "text" => "Hello World"
      }

      with_mock Req, [post: fn _url, _opts -> 
        headers = [{"x-rate-limit-reset", "1234567890"}]
        {:ok, %Req.Response{status: 429, headers: headers, body: "Too Many Requests"}}
      end] do
        assert {:error, %{reason: :rate_limit, retry_after: "1234567890"}} = CreateTweetPrism.handler(input)
      end
    end

    test "handles quote tweet and media ids" do
      input = %{
        "token" => "test_token",
        "text" => "Look at this",
        "quote_tweet_id" => "9999",
        "media_ids" => ["media1", "media2"]
      }

      response_body = %{
        "data" => %{
          "id" => "12345",
          "text" => "Look at this"
        }
      }

      with_mock Req, [post: fn _url, opts -> 
        assert opts[:json][:quote_tweet_id] == "9999"
        assert opts[:json][:media][:media_ids] == ["media1", "media2"]
        headers = [{"x-rate-limit-remaining", "98"}]
        {:ok, %Req.Response{status: 201, body: response_body, headers: headers}}
      end] do
        assert {:ok, _} = CreateTweetPrism.handler(input)
      end
    end
  end
end
