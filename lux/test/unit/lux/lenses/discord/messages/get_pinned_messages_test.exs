defmodule Lux.Lenses.Discord.Messages.GetPinnedMessagesTest do
  @moduledoc """
  Test suite for the GetPinnedMessages module.
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Messages.GetPinnedMessages

  @channel_id "123456789012345678"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully fetches pinned messages" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/:channel_id/pins"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{
            "id" => "111111111111111111",
            "content" => "Pinned announcement",
            "author" => %{
              "id" => "222222222222222222",
              "username" => "Admin"
            }
          },
          %{
            "id" => "333333333333333333",
            "content" => "Another pin",
            "author" => %{
              "id" => "444444444444444444",
              "username" => "Mod"
            }
          }
        ]))
      end)

      assert {:ok, messages} = GetPinnedMessages.focus(%{channel_id: @channel_id}, %{})

      assert length(messages) == 2
      [first, second] = messages
      assert first.id == "111111111111111111"
      assert first.content == "Pinned announcement"
      assert first.author.username == "Admin"
      assert second.id == "333333333333333333"
    end

    test "handles empty pinned messages" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([]))
      end)

      assert {:ok, []} = GetPinnedMessages.focus(%{channel_id: @channel_id}, %{})
    end

    test "handles Discord API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, %{"message" => "Missing Permissions"}} =
        GetPinnedMessages.focus(%{channel_id: @channel_id}, %{})
    end
  end
end
