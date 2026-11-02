defmodule Lux.Integrations.Twitter.TweetsTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Twitter.Tweets

  describe "create_tweet/2" do
    test "posts text tweet" do
      plug = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["text"] == "Hello World from Lux!"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(201, Jason.encode!(%{"data" => %{"id" => "111", "text" => decoded["text"]}}))
      end

      {:ok, result} =
        Tweets.create_tweet(%{text: "Hello World from Lux!"}, %{plug: plug})

      assert result["data"]["id"] == "111"
      assert result["data"]["text"] == "Hello World from Lux!"
    end

    test "posts tweet with media IDs and quote tweet" do
      plug = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["media"]["media_ids"] == ["media_1", "media_2"]
        assert decoded["quote_tweet_id"] == "quote_999"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(201, Jason.encode!(%{"data" => %{"id" => "222", "text" => decoded["text"]}}))
      end

      {:ok, result} =
        Tweets.create_tweet(
          %{
            text: "Quoting a tweet with images",
            media_ids: ["media_1", "media_2"],
            quote_tweet_id: "quote_999"
          },
          %{plug: plug}
        )

      assert result["data"]["id"] == "222"
    end
  end

  describe "delete_tweet/2 and get_tweet/2" do
    test "deletes tweet by ID" do
      plug = fn conn ->
        assert conn.request_path == "/tweets/12345"
        assert conn.method == "DELETE"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => %{"deleted" => true}}))
      end

      {:ok, result} = Tweets.delete_tweet("12345", %{plug: plug})
      assert result["data"]["deleted"] == true
    end

    test "gets tweet with fields and expansions" do
      plug = fn conn ->
        assert conn.request_path == "/tweets/12345"
        assert conn.method == "GET"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "data" => %{
              "id" => "12345",
              "text" => "Target Tweet",
              "public_metrics" => %{"like_count" => 42, "retweet_count" => 10}
            }
          })
        )
      end

      {:ok, result} = Tweets.get_tweet("12345", %{plug: plug})
      assert result["data"]["id"] == "12345"
      assert result["data"]["public_metrics"]["like_count"] == 42
    end
  end

  describe "create_thread/2" do
    test "chains tweets sequentially with in_reply_to_tweet_id" do
      # Agent to track sequentially posted tweets
      {:ok, pid} = Agent.start_link(fn -> [] end)

      plug = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        count = Agent.get_and_update(pid, fn list -> {length(list), [decoded | list]} end)
        new_id = "thread_tx_#{count + 1}"

        if count > 0 do
          expected_prev_id = "thread_tx_#{count}"
          assert decoded["reply"]["in_reply_to_tweet_id"] == expected_prev_id
        end

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(201, Jason.encode!(%{"data" => %{"id" => new_id, "text" => decoded["text"]}}))
      end

      thread_tweets = [
        "1/3 Welcome to our deep dive on autonomous agents.",
        "2/3 Lux powers scalable, multi-agent organizations with beams and prisms.",
        "3/3 Learn more at docs.spectral.finance"
      ]

      {:ok, results} = Tweets.create_thread(thread_tweets, %{plug: plug})
      assert length(results) == 3
      assert hd(results)["data"]["id"] == "thread_tx_1"
      assert List.last(results)["data"]["id"] == "thread_tx_3"
    end
  end
end
