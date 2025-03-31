defmodule Lux.Lenses.Discord.Channels.ListChannelsTest do
  @moduledoc """
  Test suite for the ListChannels module.
  These tests verify the lens's ability to:
  - List channels from a Discord guild
  - Handle Discord API errors appropriately
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Channels.ListChannels

  @guild_id "123456789012345678"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully lists channels" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.replace(conn.request_path, ":guild_id", @guild_id) == "/api/v10/guilds/#{@guild_id}/channels"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{
            "id" => "111111111111111111",
            "name" => "general",
            "type" => 0,
            "guild_id" => @guild_id
          },
          %{
            "id" => "222222222222222222",
            "name" => "announcements",
            "type" => 0,
            "guild_id" => @guild_id
          }
        ]))
      end)

      assert {:ok, [
        %{
          id: "111111111111111111",
          name: "general",
          type: 0,
          guild_id: @guild_id
        },
        %{
          id: "222222222222222222",
          name: "announcements",
          type: 0,
          guild_id: @guild_id
        }
      ]} = ListChannels.focus(%{
        "guild_id" => @guild_id
      }, %{})
    end

    test "handles Discord API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.replace(conn.request_path, ":guild_id", @guild_id) == "/api/v10/guilds/#{@guild_id}/channels"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, %{"message" => "Missing Permissions"}} = ListChannels.focus(%{
        "guild_id" => @guild_id
      }, %{})
    end
  end
end
