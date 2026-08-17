defmodule Lux.Prisms.Discord.Server.ListGuildChannelsTest do
  @moduledoc """
  Test suite for ListGuildChannels prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Server.ListGuildChannels

  @guild_id "123456789012345678"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully lists guild channels" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/channels"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "111111111111111111",
          "type" => 0,
          "name" => "general",
          "position" => 0,
          "parent_id" => nil,
          "topic" => "General chat",
          "nsfw" => false
        }))
      end)

      assert {:ok, %{
        channels: [%{
          id: "111111111111111111",
          type: 0,
          name: "general",
          position: 0,
          parent_id: nil,
          topic: "General chat",
          nsfw: false
        }]
      }} = ListGuildChannels.handler(
        %{
          guild_id: @guild_id,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/channels"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, {403, "Missing Permissions"}} = ListGuildChannels.handler(
        %{
          guild_id: @guild_id,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end
  end
end