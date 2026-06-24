defmodule Lux.Lenses.Twitter.Tweets.CreateTweetTest do
  @moduledoc false
  use UnitAPICase, async: true
  alias Lux.Lenses.Twitter.Tweets.CreateTweet

  setup do
    Application.put_env(:lux, :api_keys, twitter: "test-twitter-token")
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully creates a tweet" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/tweets"
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

      assert {:ok, %{"id" => "123456789", "text" => "Hello from Lux!"}} =
        CreateTweet.focus(%{text: "Hello from Lux!"})
    end

    test "handles Twitter API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/tweets"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-twitter-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "errors" => [%{"message" => "Forbidden", "code" => 32}]
        }))
      end)

      assert {:error, [%{"message" => "Forbidden"}]} =
        CreateTweet.focus(%{text: "Hello from Lux!"})
    end
  end
end
