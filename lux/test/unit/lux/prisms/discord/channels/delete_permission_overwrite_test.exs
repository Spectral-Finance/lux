defmodule Lux.Prisms.Discord.Channels.DeletePermissionOverwriteTest do
  @moduledoc """
  Test suite for deleting Discord channel permission overwrites.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Channels.DeletePermissionOverwrite

  @channel_id "123456789012345678"
  @overwrite_id "987654321098765432"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully deletes a permission overwrite" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/permissions/#{@overwrite_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]
        assert Plug.Conn.get_req_header(conn, "x-audit-log-reason") == ["cleanup"]

        Plug.Conn.send_resp(conn, 204, "")
      end)

      assert {:ok,
              %{
                deleted: true,
                channel_id: @channel_id,
                overwrite_id: @overwrite_id
              }} =
               DeletePermissionOverwrite.handler(
                 %{
                   channel_id: @channel_id,
                   overwrite_id: @overwrite_id,
                   reason: "cleanup",
                   plug: {Req.Test, DiscordClientMock}
                 },
                 @agent_ctx
               )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/permissions/#{@overwrite_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      assert {:error, {403, "Missing Permissions"}} =
               DeletePermissionOverwrite.handler(
                 %{
                   channel_id: @channel_id,
                   overwrite_id: @overwrite_id,
                   plug: {Req.Test, DiscordClientMock}
                 },
                 @agent_ctx
               )
    end
  end
end
