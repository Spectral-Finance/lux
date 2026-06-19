defmodule Lux.Lenses.Discord.Roles.ListRolesTest do
  @moduledoc """
  Test suite for ListRoles lens.
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Roles.ListRoles

  @guild_id "123456789012345678"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully lists roles" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/roles"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!([
            %{
              "id" => "111111",
              "name" => "Admin",
              "color" => 16711680,
              "hoist" => true,
              "position" => 1,
              "permissions" => "8",
              "managed" => false,
              "mentionable" => true
            }
          ])
        )
      end)

      assert {:ok, roles} = ListRoles.focus(%{guild_id: @guild_id}, %{})
      assert length(roles) == 1
      [role] = roles
      assert role.id == "111111"
      assert role.name == "Admin"
      assert role.color == 16711680
    end

    test "handles error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/roles"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      assert {:error, %{"message" => "Missing Permissions"}} =
               ListRoles.focus(%{guild_id: @guild_id}, %{})
    end
  end
end
