defmodule Lux.Prisms.YouTube.LiveChat.InsertMessageTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.Client
  alias Lux.Prisms.YouTube.LiveChat.InsertMessage

  setup do
    Application.put_env(:lux, Client, plug: {Req.Test, YouTubeClientMock})
    Req.Test.verify_on_exit!()
    :ok
  end

  test "sends a live chat text message" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/liveChat/messages"
      query = URI.decode_query(conn.query_string)
      assert query["part"] == "snippet"

      {:ok, body, _conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert decoded["snippet"]["liveChatId"] == "chat-123"
      assert decoded["snippet"]["type"] == "textMessageEvent"
      assert decoded["snippet"]["textMessageDetails"]["messageText"] == "Hello chat"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "msg-1", "snippet" => %{"displayMessage" => "Hello chat"}}))
    end)

    assert {:ok, %{id: "msg-1", message: "Hello chat"}} =
             InsertMessage.handler(%{live_chat_id: "chat-123", text: "Hello chat"}, %{name: "Agent"})
  end
end
