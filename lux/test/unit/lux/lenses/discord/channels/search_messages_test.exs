defmodule Lux.Lenses.Discord.Channels.SearchMessagesTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Channels.SearchMessages

  @channel_id "123456789"

  describe "focus/2" do
    test "successfully searches messages" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.replace(conn.request_path, ":channel_id", @channel_id) == "/api/v10/channels/#{@channel_id}/messages/search"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "messages" => [[%{
            "id" => "987654321",
            "content" => "Important announcement: Server maintenance",
            "author" => %{
              "id" => "111222333",
              "username" => "moderator"
            },
            "timestamp" => "2024-04-03T12:00:00.000000+00:00",
            "attachments" => [],
            "embeds" => []
          }]],
          "total_results" => 1
        }))
      end)

      assert {:ok, result} = SearchMessages.focus(%{
        channel_id: @channel_id,
        query: "important announcement",
        limit: 10,
        offset: 0
      })

      assert result.total_results == 1
      [message] = result.messages
      assert message.id == "987654321"
      assert message.content == "Important announcement: Server maintenance"
      assert message.author.id == "111222333"
      assert message.author.username == "moderator"
      assert message.timestamp == "2024-04-03T12:00:00.000000+00:00"
      assert message.attachments == []
      assert message.embeds == []
    end

    test "handles empty search results" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.replace(conn.request_path, ":channel_id", @channel_id) == "/api/v10/channels/#{@channel_id}/messages/search"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "messages" => [],
          "total_results" => 0
        }))
      end)

      assert {:ok, result} = SearchMessages.focus(%{
        channel_id: @channel_id,
        query: "nonexistent message"
      })

      assert result.total_results == 0
      assert result.messages == []
    end

    test "handles channel not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.replace(conn.request_path, ":channel_id", "invalid_id") == "/api/v10/channels/invalid_id/messages/search"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "message" => "Unknown Channel"
        }))
      end)

      assert {:error, %{"message" => "Unknown Channel"}} = SearchMessages.focus(%{
        channel_id: "invalid_id",
        query: "test"
      })
    end
  end
end
