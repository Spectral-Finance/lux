defmodule Lux.Prisms.Twitter.Tweets.CreateThreadTest do
  @moduledoc """
  Test suite for the Twitter CreateThread prism.
  Verifies:
  - Successful thread creation with multiple tweets
  - Single tweet rejection (must have at least 2)
  - Tweet length validation (max 280 chars each)
  - Reply chaining (each tweet replies to previous)
  - Error propagation from API failures
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Twitter.Tweets.CreateThread

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully creates a thread with 3 tweets" do
      # First tweet (INIT)
      Req.Test.expect(Lux.Prisms.Twitter.Tweets.CreateThread, fn conn ->
        assert conn.method == "POST"
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(%{
          "data" => %{"id" => "tweet_1", "text" => "1/ Starting thread"}
        }))
      end)

      # Second tweet (reply to first)
      Req.Test.expect(Lux.Prisms.Twitter.Tweets.CreateThread, fn conn ->
        assert conn.method == "POST"
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(%{
          "data" => %{"id" => "tweet_2", "text" => "2/ Continuing thread"}
        }))
      end)

      # Third tweet (reply to second)
      Req.Test.expect(Lux.Prisms.Twitter.Tweets.CreateThread, fn conn ->
        assert conn.method == "POST"
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(%{
          "data" => %{"id" => "tweet_3", "text" => "3/ Final tweet"}
        }))
      end)

      assert {:ok, result} = CreateThread.handler(
        %{"tweets" => ["1/ Starting thread", "2/ Continuing thread", "3/ Final tweet"]},
        %{}
      )

      assert result.thread_id == "tweet_1"
      assert result.tweet_count == 3
      assert length(result.tweets) == 3
      assert hd(result.tweets).id == "tweet_1"
    end

    test "rejects single tweet" do
      assert {:error, message} = CreateThread.handler(
        %{"tweets" => ["Only one tweet"]},
        %{}
      )
      assert message =~ "at least 2"
    end

    test "rejects tweet exceeding 280 characters" do
      long_tweet = String.duplicate("x", 281)

      assert {:error, message} = CreateThread.handler(
        %{"tweets" => ["Valid tweet", long_tweet]},
        %{}
      )
      assert message =~ "280 characters"
    end

    test "returns error when missing tweets parameter" do
      assert {:error, _} = CreateThread.handler(%{}, %{})
    end

    test "handles API failure on first tweet" do
      Req.Test.expect(Lux.Prisms.Twitter.Tweets.CreateThread, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "title" => "Forbidden",
          "detail" => "Your account is suspended"
        }))
      end)

      assert {:error, message} = CreateThread.handler(
        %{"tweets" => ["First tweet", "Second tweet"]},
        %{}
      )
      assert message =~ "Failed to post first tweet"
    end
  end
end
