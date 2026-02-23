defmodule Lux.Lenses.Twitter.Automation.GetTimelineTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.Twitter.Automation.GetTimeline

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves user timeline" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/users/123456789/tweets"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => [
            %{"id" => "101", "text" => "First tweet", "created_at" => "2024-01-01T12:00:00Z",
              "public_metrics" => %{"like_count" => 100, "retweet_count" => 20, "reply_count" => 10}},
            %{"id" => "100", "text" => "Second tweet", "created_at" => "2024-01-01T11:00:00Z",
              "public_metrics" => %{"like_count" => 50, "retweet_count" => 5, "reply_count" => 3}}
          ],
          "meta" => %{"result_count" => 2, "newest_id" => "101", "oldest_id" => "100"}
        }))
      end)

      assert {:ok, result} = GetTimeline.focus(%{"user_id" => "123456789"}, %{})
      assert length(result.tweets) == 2
      assert result.result_count == 2
      assert hd(result.tweets).id == "101"
    end

    test "handles empty timeline" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "meta" => %{"result_count" => 0}
        }))
      end)

      assert {:ok, result} = GetTimeline.focus(%{"user_id" => "999"}, %{})
      assert result.tweets == []
      assert result.result_count == 0
    end

    test "passes exclude parameter for retweets" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        params = URI.decode_query(conn.query_string)
        assert params["exclude"] == "retweets"
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => [], "meta" => %{"result_count" => 0}
        }))
      end)

      GetTimeline.focus(%{"user_id" => "123", "exclude" => ["retweets"]}, %{})
    end

    test "handles authorization error" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn |> Plug.Conn.send_resp(401, "")
      end)

      assert {:error, :unauthorized} = GetTimeline.focus(%{"user_id" => "123"}, %{})
    end
  end
end
