defmodule Lux.Lenses.Discord.Guilds.ListEmojisTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Guilds.ListEmojis

  @guild_id "123456789"

  describe "focus/2" do
    test "successfully lists guild emojis" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.replace(conn.request_path, ":guild_id", @guild_id) == "/api/v10/guilds/#{@guild_id}/emojis"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([%{
          "id" => "987654321",
          "name" => "custom_emoji",
          "roles" => ["role1", "role2"],
          "user" => %{
            "id" => "111222333",
            "username" => "creator"
          },
          "require_colons" => true,
          "managed" => false,
          "animated" => false,
          "available" => true
        }]))
      end)

      assert {:ok, [emoji]} = ListEmojis.focus(%{
        guild_id: @guild_id
      })

      assert emoji.id == "987654321"
      assert emoji.name == "custom_emoji"
      assert emoji.roles == ["role1", "role2"]
      assert emoji.user.id == "111222333"
      assert emoji.user.username == "creator"
      assert emoji.require_colons == true
      assert emoji.managed == false
      assert emoji.animated == false
      assert emoji.available == true
    end

    test "handles guild not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.replace(conn.request_path, ":guild_id", "invalid_id") == "/api/v10/guilds/invalid_id/emojis"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "message" => "Unknown Guild"
        }))
      end)

      assert {:error, %{"message" => "Unknown Guild"}} = ListEmojis.focus(%{
        guild_id: "invalid_id"
      })
    end
  end
end
