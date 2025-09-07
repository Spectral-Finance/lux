defmodule Lux.Lenses.Discord.Interactions.ReadSlashCommandTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Interactions.ReadSlashCommand

  @interaction_id "123456789012345678"

  describe "focus/2" do
    test "successfully reads slash command with options" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/interactions/:interaction_id"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @interaction_id,
          "data" => %{
            "id" => "987654321",
            "name" => "test",
            "options" => [
              %{
                "name" => "user",
                "type" => 6,
                "value" => "111222333"
              }
            ]
          },
          "guild_id" => "444555666",
          "channel_id" => "777888999",
          "member" => %{
            "user" => %{
              "id" => "111222333",
              "username" => "testuser"
            },
            "roles" => ["role1", "role2"]
          }
        }))
      end)

      assert {:ok, response} = ReadSlashCommand.focus(%{
        interaction_id: @interaction_id
      })

      assert response.id == @interaction_id
      assert response.command_id == "987654321"
      assert response.command_name == "test"
      assert length(response.options) == 1

      [option] = response.options
      assert option["name"] == "user"
      assert option["type"] == 6
      assert option["value"] == "111222333"

      assert response.guild_id == "444555666"
      assert response.channel_id == "777888999"
      assert response.member.user_id == "111222333"
      assert response.member.username == "testuser"
      assert response.member.roles == ["role1", "role2"]
    end

    test "successfully reads slash command without options" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/interactions/:interaction_id"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @interaction_id,
          "data" => %{
            "id" => "987654321",
            "name" => "test"
          },
          "guild_id" => "444555666",
          "channel_id" => "777888999",
          "member" => %{
            "user" => %{
              "id" => "111222333",
              "username" => "testuser"
            },
            "roles" => ["role1", "role2"]
          }
        }))
      end)

      assert {:ok, response} = ReadSlashCommand.focus(%{
        interaction_id: @interaction_id
      })

      assert response.id == @interaction_id
      assert response.command_id == "987654321"
      assert response.command_name == "test"
      assert response.options == []
      assert response.guild_id == "444555666"
      assert response.channel_id == "777888999"
      assert response.member.user_id == "111222333"
      assert response.member.username == "testuser"
      assert response.member.roles == ["role1", "role2"]
    end

    test "handles interaction not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/interactions/:interaction_id"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "message" => "Unknown Interaction"
        }))
      end)

      assert {:error, %{"message" => "Unknown Interaction"}} = ReadSlashCommand.focus(%{
        interaction_id: "invalid_id"
      })
    end
  end
end
