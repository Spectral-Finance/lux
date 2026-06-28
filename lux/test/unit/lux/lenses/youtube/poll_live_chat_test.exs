defmodule Lux.Lenses.YouTube.PollLiveChatTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.YouTube.PollLiveChat
  alias Lux.Integrations.YouTube.Client

  setup do
    Application.put_env(:lux, Client, plug: {Req.Test, Client})
    Application.put_env(:lux, :api_keys, [youtube_api_key: "test_api_key"])
    Req.Test.verify_on_exit!()
    
    %{
      config: %Client.Config{
        api_key: "test_api_key",
        access_token: nil,
        dry_run: false
      }
    }
  end

  describe "focus/3" do
    test "polls live chat and returns new messages" do
      Req.Test.expect(Client, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/liveChat/messages"
        
        query = URI.decode_query(conn.query_string)
        assert query["key"] == "test_api_key"
        assert query["liveChatId"] == "chat123"
        
        Req.Test.json(conn, %{
          "nextPageToken" => "next_token",
          "pollingIntervalMillis" => 5000,
          "items" => [
            %{"id" => "msg1", "snippet" => %{"displayMessage" => "Hello!"}}
          ]
        })
      end)

      params = %{live_chat_id: "chat123", page_token: nil}

      assert {:ok, result} = PollLiveChat.focus(params, nil)
      
      assert result.messages |> length() == 1
      assert result.next_page_token == "next_token"
      assert result.polling_interval_millis == 5000
    end
  end
end
