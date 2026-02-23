defmodule Lux.Lenses.Twitter.Tweets.ListUserTweetsTest do
  @moduledoc """
  Test suite for the ListUserTweets lens.
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Twitter.Tweets.ListUserTweets

  @user_id "123456789"

  describe "after_focus/1" do
    test "successfully transforms tweet list response" do
      response = %{
        "data" => [
          %{"id" => "1001", "text" => "Hello world!"},
          %{"id" => "1002", "text" => "Another tweet"}
        ],
        "meta" => %{
          "result_count" => 2,
          "next_token" => "next_page_token",
          "newest_id" => "1002",
          "oldest_id" => "1001"
        }
      }

      assert {:ok, result} = ListUserTweets.after_focus(response)
      assert length(result.data) == 2
      assert hd(result.data).id == "1001"
      assert hd(result.data).text == "Hello world!"
      assert result.meta.result_count == 2
      assert result.meta.next_token == "next_page_token"
      assert result.meta.newest_id == "1002"
      assert result.meta.oldest_id == "1001"
    end

    test "handles response without meta" do
      response = %{
        "data" => [
          %{"id" => "1001", "text" => "Hello world!"}
        ]
      }

      assert {:ok, result} = ListUserTweets.after_focus(response)
      assert length(result.data) == 1
      assert result.meta == %{}
    end

    test "includes optional tweet fields when present" do
      response = %{
        "data" => [
          %{
            "id" => "1001",
            "text" => "Tweet with metrics",
            "author_id" => "987654321",
            "created_at" => "2024-01-01T00:00:00Z",
            "public_metrics" => %{
              "retweet_count" => 5,
              "reply_count" => 3,
              "like_count" => 42,
              "quote_count" => 1
            }
          }
        ],
        "meta" => %{"result_count" => 1}
      }

      assert {:ok, result} = ListUserTweets.after_focus(response)
      tweet = hd(result.data)
      assert tweet.author_id == "987654321"
      assert tweet.created_at == "2024-01-01T00:00:00Z"
      assert tweet.public_metrics.like_count == 42
      assert tweet.public_metrics.retweet_count == 5
    end

    test "handles API error response" do
      response = %{
        "errors" => [%{
          "title" => "Invalid Request",
          "detail" => "user_id is not valid"
        }]
      }

      assert {:error, %{title: "Invalid Request", detail: "user_id is not valid"}} =
        ListUserTweets.after_focus(response)
    end

    test "handles title/detail error format" do
      response = %{
        "title" => "Not Found Error",
        "detail" => "User not found"
      }

      assert {:error, %{title: "Not Found Error", detail: "User not found"}} =
        ListUserTweets.after_focus(response)
    end

    test "handles unexpected response format" do
      assert {:error, %{title: "Unexpected response"}} =
        ListUserTweets.after_focus(%{"unknown" => "format"})
    end
  end

  describe "focus/2 integration" do
    setup do
      Req.Test.verify_on_exit!()
      :ok
    end

    test "successfully fetches user tweets" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.contains?(conn.request_path, @user_id)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => [
            %{"id" => "1001", "text" => "First tweet"},
            %{"id" => "1002", "text" => "Second tweet"}
          ],
          "meta" => %{
            "result_count" => 2,
            "newest_id" => "1002",
            "oldest_id" => "1001"
          }
        }))
      end)

      assert {:ok, result} = ListUserTweets.focus(%{"user_id" => @user_id})
      assert length(result.data) == 2
      assert result.meta.result_count == 2
    end
  end
end
