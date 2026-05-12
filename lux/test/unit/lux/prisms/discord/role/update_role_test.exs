defmodule Lux.Prisms.Discord.Role.UpdateRoleTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Discord.Role.UpdateRole

  @guild_id "123456789012345678"
  @role_id "987654321098765432"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "updates a role's name and permission settings" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/roles/#{@role_id}"

        {:ok, body, conn} = Plug.Conn.read_body(conn)

        assert Jason.decode!(body) == %{
                 "name" => "Operators",
                 "permissions" => "1024",
                 "hoist" => true,
                 "mentionable" => false
               }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "id" => @role_id,
            "name" => "Operators",
            "permissions" => "1024",
            "position" => 4
          })
        )
      end)

      assert {:ok,
              %{
                updated: true,
                role_id: @role_id,
                name: "Operators",
                permissions: "1024",
                position: 4
              }} =
               UpdateRole.handler(
                 %{
                   guild_id: @guild_id,
                   role_id: @role_id,
                   name: "Operators",
                   permissions: "1024",
                   hoist: true,
                   mentionable: false
                 },
                 @agent_ctx
               )
    end

    test "requires at least one mutable role field" do
      assert {:error, "At least one role field is required"} =
               UpdateRole.handler(%{guild_id: @guild_id, role_id: @role_id}, @agent_ctx)
    end
  end
end
