defmodule Lux.Prisms.YouTube.SendChatMessageTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.YouTube.SendChatMessage
  alias Lux.Integrations.YouTube.Client

  setup do
    Application.put_env(:lux, Client, plug: {Req.Test, Client})
    Application.put_env(:lux, :api_keys, [youtube_api_key: "test_api_key"])
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "sends a chat message to the live chat" do
      Req.Test.expect(Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/liveChat/messages"
        
        {:ok, body, _} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["snippet"]["liveChatId"] == "chat123"
        assert decoded["snippet"]["textMessageDetails"]["messageText"] == "Hello World!"
        
        Req.Test.json(conn, %{"id" => "msg123"})
      end)

      params = %{live_chat_id: "chat123", message_text: "Hello World!", dry_run: false}
      
      assert {:ok, result} = SendChatMessage.handler(params, nil)
      assert result["id"] == "msg123"
    end
  end
end
