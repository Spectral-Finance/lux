defmodule Lux.Prisms.Discord.Channels.SetPermissionOverwriteTest do
  @moduledoc """
  Test suite for setting Discord channel permission overwrites.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Channels.SetPermissionOverwrite

  @channel_id "123456789012345678"
  @overwrite_id "987654321098765432"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully creates or updates a permission overwrite" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/permissions/#{@overwrite_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]
        assert Plug.Conn.get_req_header(conn, "x-audit-log-reason") == ["agent+approval"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)

        assert Jason.decode!(body) == %{
                 "type" => 0,
                 "allow" => "1024",
                 "deny" => "2048"
               }

        Plug.Conn.send_resp(conn, 204, "")
      end)

      assert {:ok,
              %{
                updated: true,
                channel_id: @channel_id,
                overwrite_id: @overwrite_id,
                type: 0,
                allow: "1024",
                deny: "2048"
              }} =
               SetPermissionOverwrite.handler(
                 %{
                   channel_id: @channel_id,
                   overwrite_id: @overwrite_id,
                   type: 0,
                   allow: 1024,
                   deny: "2048",
                   reason: "agent approval",
                   plug: {Req.Test, DiscordClientMock}
                 },
                 @agent_ctx
               )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/permissions/#{@overwrite_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      assert {:error, {403, "Missing Permissions"}} =
               SetPermissionOverwrite.handler(
                 %{
                   channel_id: @channel_id,
                   overwrite_id: @overwrite_id,
                   type: 1,
                   allow: "0",
                   deny: "2048",
                   plug: {Req.Test, DiscordClientMock}
                 },
                 @agent_ctx
               )
    end
  end
end
