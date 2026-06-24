defmodule Lux.Lenses.Twitter.Tweets.LookupTweetTest do
  @moduledoc false
  use UnitAPICase, async: true
  alias Lux.Lenses.Twitter.Tweets.LookupTweet

  setup do
    Application.put_env(:lux, :api_keys, twitter: "test-twitter-token")
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully looks up a tweet" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-twitter-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "id" => "123456789",
            "text" => "Hello from Lux!"
          }
        }))
      end)

      assert {:ok, %{data: %{"id" => "123456789"}}} = LookupTweet.focus(%{id: "123456789"})
    end

    test "handles tweet not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "errors" => [%{"message" => "Tweet not found", "code" => 34}]
        }))
      end)

      assert {:error, [%{"message" => "Tweet not found"}]} = LookupTweet.focus(%{id: "999999999"})
    end
  end
end
