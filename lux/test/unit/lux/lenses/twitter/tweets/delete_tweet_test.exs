defmodule Lux.Lenses.Twitter.Tweets.DeleteTweetTest do
  @moduledoc false
  use UnitAPICase, async: true
  alias Lux.Lenses.Twitter.Tweets.DeleteTweet

  setup do
    Application.put_env(:lux, :api_keys, twitter: "test-twitter-token")
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully deletes a tweet" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/2/tweets/123456789"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-twitter-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{"deleted" => true}
        }))
      end)

      assert {:ok, %{deleted: true}} = DeleteTweet.focus(%{id: "123456789"})
    end

    test "handles deletion error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "DELETE"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-twitter-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "errors" => [%{"message" => "Tweet not found", "code" => 34}]
        }))
      end)

      assert {:error, [%{"message" => "Tweet not found"}]} =
        DeleteTweet.focus(%{id: "999999999"})
    end
  end
end
