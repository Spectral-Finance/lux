defmodule Lux.Lenses.Discord.Guilds.ListStickersTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Guilds.ListStickers

  @guild_id "123456789"

  describe "focus/2" do
    test "successfully lists guild stickers" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.replace(conn.request_path, ":guild_id", @guild_id) == "/api/v10/guilds/#{@guild_id}/stickers"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([%{
          "id" => "987654321",
          "name" => "custom_sticker",
          "description" => "A cool sticker",
          "tags" => "cool,awesome",
          "type" => 1,
          "format_type" => 1,
          "available" => true,
          "guild_id" => @guild_id,
          "user" => %{
            "id" => "111222333",
            "username" => "creator"
          }
        }]))
      end)

      assert {:ok, [sticker]} = ListStickers.focus(%{
        guild_id: @guild_id
      })

      assert sticker.id == "987654321"
      assert sticker.name == "custom_sticker"
      assert sticker.description == "A cool sticker"
      assert sticker.tags == "cool,awesome"
      assert sticker.type == 1
      assert sticker.format_type == 1
      assert sticker.available == true
      assert sticker.guild_id == @guild_id
      assert sticker.user.id == "111222333"
      assert sticker.user.username == "creator"
    end

    test "handles guild not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.replace(conn.request_path, ":guild_id", "invalid_id") == "/api/v10/guilds/invalid_id/stickers"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "message" => "Unknown Guild"
        }))
      end)

      assert {:error, %{"message" => "Unknown Guild"}} = ListStickers.focus(%{
        guild_id: "invalid_id"
      })
    end
  end
end
