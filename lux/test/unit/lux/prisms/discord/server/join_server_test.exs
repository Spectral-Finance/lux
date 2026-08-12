defmodule Lux.Prisms.Discord.Server.JoinServerTest do
  @moduledoc """
  Test suite for JoinServer prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Server.JoinServer

  @invite_code "abc123xyz"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully joins a server via invite" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/invites/#{@invite_code}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "guild" => %{
            "id" => "123456789012345678",
            "name" => "Test Guild"
          }
        }))
      end)

      assert {:ok, %{
        joined: true,
        guild_id: "123456789012345678",
        guild_name: "Test Guild"
      }} = JoinServer.handler(
        %{
          invite_code: @invite_code,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/invites/#{@invite_code}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "message" => "Unknown Invite"
        }))
      end)

      assert {:error, {404, "Unknown Invite"}} = JoinServer.handler(
        %{
          invite_code: @invite_code,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end
  end
end