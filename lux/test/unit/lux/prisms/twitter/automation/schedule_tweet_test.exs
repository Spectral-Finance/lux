defmodule Lux.Prisms.Twitter.Automation.ScheduleTweetTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Twitter.Automation.ScheduleTweet

  @future_time DateTime.utc_now() |> DateTime.add(3600) |> DateTime.to_iso8601()
  @agent %{name: "SchedulerBot"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully schedules a tweet" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/tweets"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(%{
          "data" => %{"id" => "tweet_scheduled_123", "text" => "Hello world!"}
        }))
      end)

      assert {:ok, result} = ScheduleTweet.handler(%{
        text: "Hello world!",
        scheduled_at: @future_time
      }, @agent)

      assert result.scheduled == true
      assert result.status in ["scheduled", "queued"]
      assert result.text == "Hello world!"
    end

    test "returns error for text exceeding 280 characters" do
      long_text = String.duplicate("a", 281)
      assert {:error, message} = ScheduleTweet.handler(%{
        text: long_text,
        scheduled_at: @future_time
      }, @agent)
      assert message =~ "280 characters"
    end

    test "returns error for empty text" do
      assert {:error, message} = ScheduleTweet.handler(%{
        text: "",
        scheduled_at: @future_time
      }, @agent)
      assert message =~ "empty"
    end

    test "returns error for past scheduled_at time" do
      past_time = DateTime.utc_now() |> DateTime.add(-3600) |> DateTime.to_iso8601()
      assert {:error, message} = ScheduleTweet.handler(%{
        text: "Hello!",
        scheduled_at: past_time
      }, @agent)
      assert message =~ "future"
    end

    test "returns error for invalid timestamp format" do
      assert {:error, message} = ScheduleTweet.handler(%{
        text: "Hello!",
        scheduled_at: "not-a-timestamp"
      }, @agent)
      assert message =~ "ISO 8601"
    end

    test "includes reply_to_tweet_id when specified" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["reply"]["in_reply_to_tweet_id"] == "999"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(%{
          "data" => %{"id" => "reply123", "text" => "Reply!"}
        }))
      end)

      assert {:ok, result} = ScheduleTweet.handler(%{
        text: "Reply!",
        scheduled_at: @future_time,
        reply_to_tweet_id: "999"
      }, @agent)
      assert result.scheduled == true
    end

    test "returns error for missing required parameters" do
      assert {:error, _} = ScheduleTweet.handler(%{text: "Missing scheduled_at"}, @agent)
    end
  end
end
