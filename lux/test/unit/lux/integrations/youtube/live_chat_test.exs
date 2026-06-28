defmodule Lux.Integrations.YouTube.LiveChatTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.Client
  alias Lux.Integrations.YouTube.LiveChat

  setup do
    Application.put_env(:lux, Client, plug: {Req.Test, Client})
    Req.Test.verify_on_exit!()
    
    %{
      config: %Client.Config{
        api_key: "test_api_key",
        access_token: nil,
        dry_run: false
      }
    }
  end

  describe "send_message/3" do
    test "sends a chat message to a live chat", %{config: config} do
      Req.Test.expect(Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/liveChat/messages"
        assert conn.query_string == "key=test_api_key&part=snippet"
        
        {:ok, body, _} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["snippet"]["liveChatId"] == "chat123"
        assert decoded["snippet"]["type"] == "textMessageEvent"
        assert decoded["snippet"]["textMessageDetails"]["messageText"] == "Hello from Lux!"
        
        Req.Test.json(conn, %{"id" => "msg123", "snippet" => %{"displayMessage" => "Hello from Lux!"}})
      end)

      assert {:ok, result} = LiveChat.send_message("chat123", "Hello from Lux!", config)
      assert result["id"] == "msg123"
    end
  end

  describe "list_messages/3" do
    test "fetches messages from a live chat", %{config: config} do
      Req.Test.expect(Client, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/liveChat/messages"
        
        query = URI.decode_query(conn.query_string)
        assert query["key"] == "test_api_key"
        assert query["liveChatId"] == "chat123"
        assert query["part"] == "id,snippet,authorDetails"
        
        Req.Test.json(conn, %{
          "nextPageToken" => "token123",
          "pollingIntervalMillis" => 5000,
          "items" => [
            %{"id" => "msg1", "snippet" => %{"displayMessage" => "Hi"}}
          ]
        })
      end)

      assert {:ok, result} = LiveChat.list_messages("chat123", nil, config)
      assert result["nextPageToken"] == "token123"
      assert length(result["items"]) == 1
    end
    
    test "includes pageToken when provided", %{config: config} do
      Req.Test.expect(Client, fn conn ->
        assert conn.query_string =~ "pageToken=old_token"
        Req.Test.json(conn, %{"items" => []})
      end)

      assert {:ok, _} = LiveChat.list_messages("chat123", "old_token", config)
    end
  end
end
