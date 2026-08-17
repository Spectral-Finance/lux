defmodule Lux.Prisms.Discord.Server.LeaveServerTest do
  @moduledoc """
  Test suite for LeaveServer prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Server.LeaveServer

  @guild_id "123456789012345678"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully leaves a server" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/users/@me/guilds/#{@guild_id}"

        Plug.Conn.send_resp(conn, 204, "")
      end)

      assert {:ok, %{left: true, guild_id: @guild_id}} = LeaveServer.handler(
        %{
          guild_id: @guild_id,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/users/@me/guilds/#{@guild_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, {403, "Missing Permissions"}} = LeaveServer.handler(
        %{
          guild_id: @guild_id,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end
  end
end