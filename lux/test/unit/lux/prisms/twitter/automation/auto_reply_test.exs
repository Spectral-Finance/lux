defmodule Lux.Prisms.Twitter.Automation.AutoReplyTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Twitter.Automation.AutoReply

  @agent %{name: "ReplyBot"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sends auto-reply" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/tweets"
        {:ok, body, _} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["reply"]["in_reply_to_tweet_id"] == "tweet_original_123"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(%{
          "data" => %{"id" => "reply_456", "text" => "Thanks for reaching out!"}
        }))
      end)

      assert {:ok, result} = AutoReply.handler(%{
        tweet_id: "tweet_original_123",
        reply_text: "Thanks for reaching out!",
        rule_triggered: "customer_support"
      }, @agent)

      assert result.replied == true
      assert result.reply_tweet_id == "reply_456"
      assert result.replied_to_tweet_id == "tweet_original_123"
      assert result.rule_triggered == "customer_support"
    end

    test "returns error for reply exceeding 280 characters" do
      long_reply = String.duplicate("a", 281)
      assert {:error, message} = AutoReply.handler(%{
        tweet_id: "123",
        reply_text: long_reply
      }, @agent)
      assert message =~ "280 characters"
    end

    test "returns error for empty reply text" do
      assert {:error, message} = AutoReply.handler(%{
        tweet_id: "123",
        reply_text: ""
      }, @agent)
      assert message =~ "empty"
    end

    test "handles rate limit response" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{"title" => "Too Many Requests"}))
      end)

      assert {:error, message} = AutoReply.handler(%{
        tweet_id: "123",
        reply_text: "Thanks!"
      }, @agent)
      assert message =~ "Rate limit"
    end

    test "returns error for missing parameters" do
      assert {:error, message} = AutoReply.handler(%{tweet_id: "123"}, @agent)
      assert message =~ "reply_text"
    end

    test "handles API error with status code" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"detail" => "You cannot reply to this tweet"}))
      end)

      assert {:error, message} = AutoReply.handler(%{
        tweet_id: "123",
        reply_text: "Hello!"
      }, @agent)
      assert message =~ "Failed to reply"
    end
  end
end
