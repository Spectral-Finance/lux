defmodule Lux.Lenses.Discord.Channels.GetPinnedMessagesTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Channels.GetPinnedMessages

  @channel_id "123456789"

  describe "focus/2" do
    test "successfully gets pinned messages" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.replace(conn.request_path, ":channel_id", @channel_id) == "/api/v10/channels/#{@channel_id}/pins"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([%{
          "id" => "987654321",
          "content" => "Important announcement!",
          "author" => %{
            "id" => "111222333",
            "username" => "moderator"
          },
          "timestamp" => "2024-04-03T12:00:00.000000+00:00",
          "pinned" => true,
          "attachments" => [],
          "embeds" => []
        }]))
      end)

      assert {:ok, [message]} = GetPinnedMessages.focus(%{
        channel_id: @channel_id
      })

      assert message.id == "987654321"
      assert message.content == "Important announcement!"
      assert message.author.id == "111222333"
      assert message.author.username == "moderator"
      assert message.timestamp == "2024-04-03T12:00:00.000000+00:00"
      assert message.pinned == true
      assert message.attachments == []
      assert message.embeds == []
    end

    test "handles channel not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.replace(conn.request_path, ":channel_id", "invalid_id") == "/api/v10/channels/invalid_id/pins"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "message" => "Unknown Channel"
        }))
      end)

      assert {:error, %{"message" => "Unknown Channel"}} = GetPinnedMessages.focus(%{
        channel_id: "invalid_id"
      })
    end
  end
end
