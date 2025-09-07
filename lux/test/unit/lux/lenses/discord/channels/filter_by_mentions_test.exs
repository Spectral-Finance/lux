defmodule Lux.Lenses.Discord.Channels.FilterByMentionsTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Channels.FilterByMentions

  @channel_id "123456789"
  @user_id "111222333"

  describe "focus/2" do
    test "successfully filters messages by mentions" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.replace(conn.request_path, ":channel_id", @channel_id) == "/api/v10/channels/#{@channel_id}/messages"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]
        assert conn.query_string == "mentions=#{@user_id}&limit=50"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([%{
          "id" => "987654321",
          "content" => "Hey <@#{@user_id}>, please check this out!",
          "author" => %{
            "id" => "444555666",
            "username" => "team_lead"
          },
          "timestamp" => "2024-04-03T12:00:00.000000+00:00",
          "mentions" => [%{
            "id" => @user_id,
            "username" => "developer"
          }]
        }]))
      end)

      assert {:ok, [message]} = FilterByMentions.focus(%{
        channel_id: @channel_id,
        mentioned_user_ids: [@user_id],
        limit: 50
      })

      assert message.id == "987654321"
      assert message.content == "Hey <@#{@user_id}>, please check this out!"
      assert message.author.id == "444555666"
      assert message.author.username == "team_lead"
      assert message.timestamp == "2024-04-03T12:00:00.000000+00:00"
      [mention] = message.mentions
      assert mention.id == @user_id
      assert mention.username == "developer"
    end

    test "handles no messages found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.replace(conn.request_path, ":channel_id", @channel_id) == "/api/v10/channels/#{@channel_id}/messages"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]
        assert conn.query_string == "mentions=#{@user_id}&limit=50"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([]))
      end)

      assert {:ok, []} = FilterByMentions.focus(%{
        channel_id: @channel_id,
        mentioned_user_ids: [@user_id],
        limit: 50
      })
    end

    test "handles channel not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.replace(conn.request_path, ":channel_id", "invalid_id") == "/api/v10/channels/invalid_id/messages"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "message" => "Unknown Channel"
        }))
      end)

      assert {:error, %{"message" => "Unknown Channel"}} = FilterByMentions.focus(%{
        channel_id: "invalid_id",
        mentioned_user_ids: [@user_id]
      })
    end
  end
end
