defmodule Lux.Lenses.Discord.Roles.ListRolesTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Discord.Roles.ListRoles

  @guild_id "123456789012345678"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "lists roles for a guild" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/:guild_id/roles"

        query = URI.decode_query(conn.query_string)
        assert query["guild_id"] == @guild_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!([
            %{
              "id" => "111111111111111111",
              "name" => "@everyone",
              "permissions" => "0",
              "position" => 0,
              "color" => 0,
              "managed" => false,
              "mentionable" => false
            },
            %{
              "id" => "222222222222222222",
              "name" => "Operators",
              "permissions" => "1024",
              "position" => 3,
              "color" => 1_193_046,
              "managed" => false,
              "mentionable" => true
            }
          ])
        )
      end)

      assert {:ok, roles} = ListRoles.focus(%{guild_id: @guild_id}, %{})
      assert Enum.map(roles, & &1.name) == ["@everyone", "Operators"]
      assert Enum.at(roles, 1).permissions == "1024"
      assert Enum.at(roles, 1).mentionable == true
    end

    test "handles Discord API errors" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/:guild_id/roles"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      assert {:error, %{"message" => "Missing Permissions"}} =
               ListRoles.focus(%{guild_id: @guild_id}, %{})
    end
  end
end
