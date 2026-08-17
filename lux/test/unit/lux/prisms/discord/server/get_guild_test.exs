defmodule Lux.Prisms.Discord.Server.GetGuildTest do
  @moduledoc """
  Test suite for GetGuild prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Server.GetGuild

  @guild_id "123456789012345678"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully retrieves a guild" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @guild_id,
          "name" => "Test Guild",
          "icon" => "abc123",
          "owner_id" => "987654321098765432",
          "region" => "us-east",
          "afk_timeout" => 300,
          "verification_level" => 1,
          "default_message_notifications" => 0,
          "explicit_content_filter" => 1,
          "roles" => [],
          "emojis" => [],
          "features" => [],
          "mfa_level" => 1,
          "premium_tier" => 0,
          "preferred_locale" => "en-US",
          "max_members" => 5000,
          "approximate_member_count" => 100,
          "approximate_presence_count" => 50
        }))
      end)

      assert {:ok, %{
        id: @guild_id,
        name: "Test Guild",
        icon: "abc123",
        owner_id: "987654321098765432",
        region: "us-east",
        approximate_member_count: 100
      }} = GetGuild.handler(
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
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "message" => "Unknown Guild"
        }))
      end)

      assert {:error, {404, "Unknown Guild"}} = GetGuild.handler(
        %{
          guild_id: @guild_id,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end
  end
end