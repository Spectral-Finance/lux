defmodule Lux.Prisms.Discord.Channels.EditChannelPermissionsTest do
  @moduledoc """
  Test suite for the EditChannelPermissions module.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Channels.EditChannelPermissions

  @channel_id "123456789012345678"
  @overwrite_id "987654321098765432"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully edits channel permissions" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/permissions/#{@overwrite_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["type"] == 0
        assert decoded["allow"] == "1024"
        assert decoded["deny"] == "2048"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{
        updated: true,
        channel_id: @channel_id,
        overwrite_id: @overwrite_id
      }} = EditChannelPermissions.handler(
        %{
          channel_id: @channel_id,
          overwrite_id: @overwrite_id,
          type: 0,
          allow: "1024",
          deny: "2048"
        },
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, {403, "Missing Permissions"}} = EditChannelPermissions.handler(
        %{channel_id: @channel_id, overwrite_id: @overwrite_id, type: 0},
        @agent_ctx
      )
    end

    test "validates missing type" do
      assert {:error, "Missing or invalid type"} =
        EditChannelPermissions.handler(
          %{channel_id: @channel_id, overwrite_id: @overwrite_id},
          @agent_ctx
        )
    end
  end
end
