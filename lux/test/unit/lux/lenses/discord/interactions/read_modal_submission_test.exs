defmodule Lux.Lenses.Discord.Interactions.ReadModalSubmissionTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Interactions.ReadModalSubmission

  @interaction_id "123456789012345678"

  describe "focus/2" do
    test "successfully reads modal submission interaction" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/interactions/:interaction_id"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @interaction_id,
          "data" => %{
            "custom_id" => "feedback_form",
            "components" => [
              %{
                "custom_id" => "feedback_title",
                "type" => 4,
                "value" => "Great feature!"
              },
              %{
                "custom_id" => "feedback_content",
                "type" => 4,
                "value" => "This new feature is amazing..."
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

      assert {:ok, response} = ReadModalSubmission.focus(%{
        interaction_id: @interaction_id
      })

      assert response.id == @interaction_id
      assert response.custom_id == "feedback_form"
      assert length(response.components) == 2

      [title, content] = response.components
      assert title["custom_id"] == "feedback_title"
      assert title["type"] == 4
      assert title["value"] == "Great feature!"

      assert content["custom_id"] == "feedback_content"
      assert content["type"] == 4
      assert content["value"] == "This new feature is amazing..."

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

      assert {:error, %{"message" => "Unknown Interaction"}} = ReadModalSubmission.focus(%{
        interaction_id: "invalid_id"
      })
    end
  end
end
