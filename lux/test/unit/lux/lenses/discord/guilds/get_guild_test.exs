defmodule Lux.Lenses.Discord.Guilds.GetGuildTest do
  @moduledoc """
  Test suite for the GetGuild module.
  These tests verify the lens's ability to:
  - Read guild information from Discord
  - Handle Discord API errors appropriately
  - Validate input/output schemas
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Guilds.GetGuild

  @guild_id "123456789012345678"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully reads a guild" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/:guild_id"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @guild_id,
          "name" => "Test Server",
          "icon" => "1234567890abcdef",
          "owner_id" => "876543210987654321",
          "permissions" => "1071698529857",
          "features" => ["COMMUNITY", "NEWS"],
          "member_count" => 42
        }))
      end)

      assert {:ok, %{
        id: @guild_id,
        name: "Test Server",
        icon: "1234567890abcdef",
        owner_id: "876543210987654321",
        permissions: "1071698529857",
        features: ["COMMUNITY", "NEWS"],
        member_count: 42
      }} = GetGuild.focus(%{
        "guild_id" => @guild_id
      }, %{})
    end

    test "handles Discord API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/:guild_id"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, %{"message" => "Missing Permissions"}} = GetGuild.focus(%{
        "guild_id" => @guild_id
      }, %{})
    end
  end

  describe "schema validation" do
    test "validates schema" do
      lens = GetGuild.view()
      assert lens.schema.required == ["guild_id"]
      assert Map.has_key?(lens.schema.properties, :guild_id)
    end
  end
end
