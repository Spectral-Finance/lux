defmodule Lux.Prisms.Discord.Member.ListMembersTest do
  @moduledoc """
  Test suite for ListMembers prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Member.ListMembers

  @guild_id "123456789012345678"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully lists guild members" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/members?limit=2"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "user" => %{
            "id" => "111111111111111111",
            "username" => "testuser",
            "discriminator" => "0001",
            "avatar" => "abc123",
            "bot" => false
          },
          "roles" => ["222222222222222222"],
          "joined_at" => "2024-01-01T00:00:00.000000+00:00",
          "nick" => "Test User",
          "premium_since" => nil
        }))
      end)

      assert {:ok, %{
        members: [%{
          user: %{
            id: "111111111111111111",
            username: "testuser",
            discriminator: "0001",
            avatar: "abc123",
            bot: false
          },
          roles: ["222222222222222222"],
          joined_at: "2024-01-01T00:00:00.000000+00:00",
          nick: "Test User",
          premium_since: nil
        }]
      }} = ListMembers.handler(
        %{
          guild_id: @guild_id,
          limit: 2,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/members?limit=100"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, {403, "Missing Permissions"}} = ListMembers.handler(
        %{
          guild_id: @guild_id,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end
  end
end