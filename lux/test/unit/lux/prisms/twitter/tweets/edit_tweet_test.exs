defmodule Lux.Prisms.Twitter.Tweets.EditTweetTest do
  @moduledoc """
  Test suite for the EditTweet prism.
  Verifies the prism can:
  - Edit the text of a tweet
  - Return updated tweet data including edit history
  - Handle 401 unauthorized errors
  - Handle 403 forbidden (not eligible for editing)
  - Handle 404 not found errors
  - Handle 429 rate limit errors
  - Accept string-keyed params
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Twitter.Tweets.EditTweet

  @tweet_id "1234567890123456789"
  @agent %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully edits a tweet" do
      Req.Test.expect(EditTweet, fn conn ->
        assert conn.method == "PATCH"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["text"] == "Updated tweet text!"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "id" => @tweet_id,
            "text" => "Updated tweet text!",
            "edit_history_tweet_ids" => [@tweet_id]
          }
        }))
      end)

      assert {:ok, result} = EditTweet.handler(
        %{tweet_id: @tweet_id, text: "Updated tweet text!"},
        @agent
      )

      assert result.id == @tweet_id
      assert result.text == "Updated tweet text!"
      assert result.edit_history_tweet_ids == [@tweet_id]
    end

    test "accepts string-keyed params" do
      Req.Test.expect(EditTweet, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{"id" => @tweet_id, "text" => "Updated!"}
        }))
      end)

      assert {:ok, _result} = EditTweet.handler(
        %{"tweet_id" => @tweet_id, "text" => "Updated!"},
        @agent
      )
    end

    test "returns empty list when edit_history_tweet_ids not present" do
      Req.Test.expect(EditTweet, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{"id" => @tweet_id, "text" => "Updated!"}
        }))
      end)

      assert {:ok, result} = EditTweet.handler(
        %{tweet_id: @tweet_id, text: "Updated!"},
        @agent
      )

      assert result.edit_history_tweet_ids == []
    end

    test "handles unauthorized error" do
      Req.Test.expect(EditTweet, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{"title" => "Unauthorized"}))
      end)

      assert {:error, %{title: "Unauthorized"}} = EditTweet.handler(
        %{tweet_id: @tweet_id, text: "test"},
        @agent
      )
    end

    test "handles forbidden error with detail" do
      Req.Test.expect(EditTweet, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "detail" => "Tweet is no longer eligible for editing"
        }))
      end)

      assert {:error, %{title: "Forbidden", detail: "Tweet is no longer eligible for editing"}} =
               EditTweet.handler(%{tweet_id: @tweet_id, text: "test"}, @agent)
    end

    test "handles forbidden without detail" do
      Req.Test.expect(EditTweet, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{}))
      end)

      assert {:error, %{title: "Forbidden"}} =
               EditTweet.handler(%{tweet_id: @tweet_id, text: "test"}, @agent)
    end

    test "handles not found error" do
      Req.Test.expect(EditTweet, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"title" => "Not Found"}))
      end)

      assert {:error, %{title: "Not Found", detail: detail}} =
               EditTweet.handler(%{tweet_id: @tweet_id, text: "test"}, @agent)

      assert detail =~ @tweet_id
    end

    test "handles rate limit error" do
      Req.Test.expect(EditTweet, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{"title" => "Too Many Requests"}))
      end)

      assert {:error, %{title: "Rate Limited"}} =
               EditTweet.handler(%{tweet_id: @tweet_id, text: "test"}, @agent)
    end

    test "handles API error response with errors array" do
      Req.Test.expect(EditTweet, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "errors" => [%{
            "title" => "Invalid Request",
            "detail" => "Tweet text is too long"
          }]
        }))
      end)

      assert {:error, %{title: "Invalid Request", detail: "Tweet text is too long"}} =
               EditTweet.handler(%{tweet_id: @tweet_id, text: "test"}, @agent)
    end
  end
end
