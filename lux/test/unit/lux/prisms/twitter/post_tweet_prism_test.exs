defmodule Lux.Prisms.Twitter.PostTweetPrismTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Twitter.PostTweetPrism

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "returns dry run response by default" do
      {:ok, result} = PostTweetPrism.run(%{text: "Hello world"})
      assert result["dry_run"] == true
      assert String.starts_with?(result["data"]["id"], "dry_run_")
    end

    test "makes actual API call when dry_run is false" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"text" => "Actual tweet"}
        
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(%{
          "data" => %{"id" => "12345", "text" => "Actual tweet"}
        }))
      end)

      {:ok, result} = PostTweetPrism.run(%{text: "Actual tweet", dry_run: false})
      assert result["data"]["id"] == "12345"
    end

    test "handles reply_to_tweet_id" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{
          "text" => "Replying",
          "reply" => %{"in_reply_to_tweet_id" => "999"}
        }
        
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(%{
          "data" => %{"id" => "12346"}
        }))
      end)

      {:ok, result} = PostTweetPrism.run(%{
        text: "Replying",
        reply_to_tweet_id: "999",
        dry_run: false
      })
      assert result["data"]["id"] == "12346"
    end
  end
end
