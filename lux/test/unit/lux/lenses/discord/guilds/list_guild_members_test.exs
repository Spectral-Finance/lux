defmodule Lux.Lenses.Discord.Guilds.ListGuildMembersTest do
  @moduledoc """
  Test suite for the ListGuildMembers module.
  These tests verify the lens's ability to:
  - List members from a Discord guild
  - Handle pagination parameters
  - Process Discord API errors appropriately
  - Validate input/output schemas
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Guilds.ListGuildMembers

  @guild_id "123456789012345678"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully lists guild members" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/:guild_id/members"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{
            "user" => %{
              "id" => "111222333444555666",
              "username" => "user1",
              "avatar" => "avatar1"
            },
            "nick" => "nickname1",
            "roles" => ["role1", "role2"],
            "joined_at" => "2023-01-01T00:00:00.000Z",
            "premium_since" => nil,
            "pending" => false,
            "communication_disabled_until" => nil
          }
        ]))
      end)

      assert {:ok, [member]} = ListGuildMembers.focus(%{
        "guild_id" => @guild_id
      }, %{})

      assert member == %{
        user: %{
          id: "111222333444555666",
          username: "user1",
          avatar: "avatar1"
        },
        nick: "nickname1",
        roles: ["role1", "role2"],
        joined_at: "2023-01-01T00:00:00.000Z",
        premium_since: nil,
        pending: false,
        communication_disabled_until: nil
      }
    end

    test "successfully lists guild members with pagination" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/:guild_id/members"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        # Verify pagination parameters
        query = URI.decode_query(conn.query_string)
        assert query["limit"] == "50"
        assert query["after"] == "111222333444555666"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{
            "user" => %{
              "id" => "222333444555666777",
              "username" => "user2",
              "avatar" => "avatar2"
            },
            "nick" => "nickname2",
            "roles" => ["role2", "role3"],
            "joined_at" => "2023-01-02T00:00:00.000Z",
            "premium_since" => nil,
            "pending" => false,
            "communication_disabled_until" => nil
          }
        ]))
      end)

      assert {:ok, [member]} = ListGuildMembers.focus(%{
        "guild_id" => @guild_id,
        "limit" => 50,
        "after" => "111222333444555666"
      }, %{})

      assert member == %{
        user: %{
          id: "222333444555666777",
          username: "user2",
          avatar: "avatar2"
        },
        nick: "nickname2",
        roles: ["role2", "role3"],
        joined_at: "2023-01-02T00:00:00.000Z",
        premium_since: nil,
        pending: false,
        communication_disabled_until: nil
      }
    end

    test "handles Discord API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/:guild_id/members"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, %{"message" => "Missing Permissions"}} = ListGuildMembers.focus(%{
        "guild_id" => @guild_id
      }, %{})
    end
  end

  describe "schema validation" do
    test "validates schema" do
      lens = ListGuildMembers.view()
      assert lens.schema.required == ["guild_id"]
      assert Map.has_key?(lens.schema.properties, :guild_id)
      assert Map.has_key?(lens.schema.properties, :limit)
      assert Map.has_key?(lens.schema.properties, :after)
    end
  end
end
