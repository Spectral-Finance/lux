defmodule Lux.Lenses.Discord.Channels.ListActiveThreadsTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Channels.ListActiveThreads

  @channel_id "123456789"

  describe "focus/2" do
    test "successfully lists active threads" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.replace(conn.request_path, ":channel_id", @channel_id) == "/api/v10/channels/#{@channel_id}/threads/active"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "threads" => [%{
            "id" => "987654321",
            "name" => "discussion-thread",
            "owner_id" => "111222333",
            "parent_id" => @channel_id,
            "message_count" => 50,
            "member_count" => 5,
            "thread_metadata" => %{
              "archived" => false,
              "auto_archive_duration" => 1440,
              "archive_timestamp" => "2024-04-03T12:00:00.000000+00:00",
              "locked" => false
            }
          }]
        }))
      end)

      assert {:ok, [thread]} = ListActiveThreads.focus(%{
        channel_id: @channel_id
      })

      assert thread.id == "987654321"
      assert thread.name == "discussion-thread"
      assert thread.owner_id == "111222333"
      assert thread.parent_id == @channel_id
      assert thread.message_count == 50
      assert thread.member_count == 5
      assert thread.thread_metadata.archived == false
      assert thread.thread_metadata.auto_archive_duration == 1440
      assert thread.thread_metadata.archive_timestamp == "2024-04-03T12:00:00.000000+00:00"
      assert thread.thread_metadata.locked == false
    end

    test "handles channel not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.replace(conn.request_path, ":channel_id", "invalid_id") == "/api/v10/channels/invalid_id/threads/active"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "message" => "Unknown Channel"
        }))
      end)

      assert {:error, %{"message" => "Unknown Channel"}} = ListActiveThreads.focus(%{
        channel_id: "invalid_id"
      })
    end
  end
end
