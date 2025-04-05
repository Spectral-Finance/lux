defmodule Lux.Lenses.Discord.Guilds.GetGuildMemberTest do
  @moduledoc """
  Test suite for the GetGuildMember module.
  These tests verify the lens's ability to:
  - Read guild member information from Discord
  - Handle Discord API errors appropriately
  - Validate input/output schemas
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Guilds.GetGuildMember

  @guild_id "123456789012345678"
  @user_id "987654321098765432"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully reads a guild member" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/:guild_id/members/:user_id"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "user" => %{
            "id" => @user_id,
            "username" => "TestUser"
          },
          "nick" => "Custom Nick",
          "roles" => ["111111111111111111", "222222222222222222"],
          "joined_at" => "2021-01-01T00:00:00.000000+00:00"
        }))
      end)

      assert {:ok, %{
        user: %{
          id: @user_id,
          username: "TestUser"
        },
        nick: "Custom Nick",
        roles: ["111111111111111111", "222222222222222222"],
        joined_at: "2021-01-01T00:00:00.000000+00:00"
      }} = GetGuildMember.focus(%{
        "guild_id" => @guild_id,
        "user_id" => @user_id
      }, %{})
    end

    test "handles Discord API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/:guild_id/members/:user_id"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, %{"message" => "Missing Permissions"}} = GetGuildMember.focus(%{
        "guild_id" => @guild_id,
        "user_id" => @user_id
      }, %{})
    end
  end

  describe "schema validation" do
    test "validates schema" do
      lens = GetGuildMember.view()
      assert lens.schema.required == ["guild_id", "user_id"]
      assert Map.has_key?(lens.schema.properties, :guild_id)
      assert Map.has_key?(lens.schema.properties, :user_id)
    end
  end
end
