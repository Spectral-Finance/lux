defmodule Lux.Prisms.Twitter.DeleteTweetPrismTest do
  use ExUnit.Case, async: false
  import Mock
  alias Lux.Prisms.Twitter.DeleteTweetPrism

  describe "DeleteTweetPrism" do
    test "successfully deletes a tweet" do
      input = %{
        "token" => "test_token",
        "tweet_id" => "12345"
      }

      with_mock Req, [
        delete: fn url, opts -> 
          assert url == "https://api.twitter.com/2/tweets/12345"
          assert Enum.member?(opts[:headers], {"Authorization", "Bearer test_token"})
          {:ok, %Req.Response{status: 200, body: %{"data" => %{"deleted" => true}}}}
        end
      ] do
        assert {:ok, %{deleted: true}} = DeleteTweetPrism.handler(input)
      end
    end

    test "handles api error" do
      input = %{
        "token" => "test_token",
        "tweet_id" => "12345"
      }

      with_mock Req, [
        delete: fn _url, _opts -> 
          {:ok, %Req.Response{status: 404, body: %{"errors" => [%{"detail" => "Not Found"}]}}}
        end
      ] do
        assert {:error, _} = DeleteTweetPrism.handler(input)
      end
    end
  end
end
