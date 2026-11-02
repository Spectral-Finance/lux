defmodule Lux.Prisms.Discord.ChannelManagementPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Discord.ChannelManagementPrism

  describe "handler/2 actions" do
    test "creates channel via prism" do
      plug = fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/guilds/guild_123/channels"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(201, Jason.encode!(%{"id" => "chan_999", "name" => "test-chan"}))
      end

      {:ok, res} =
        ChannelManagementPrism.run(%{
          action: "create_channel",
          payload: %{guild_id: "guild_123", name: "test-chan", plug: plug}
        })

      assert res.action == "create_channel"
      assert res.result["id"] == "chan_999"
    end

    test "sets permissions via prism" do
      plug = fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/channels/chan_999/permissions/role_111"

        conn
        |> Plug.Conn.resp(204, "")
      end

      {:ok, res} =
        ChannelManagementPrism.run(%{
          action: "set_permissions",
          payload: %{
            channel_id: "chan_999",
            overwrite_id: "role_111",
            type: 0,
            allow: "1024",
            plug: plug
          }
        })

      assert res.action == "set_permissions"
      assert res.result.status == :ok
    end
  end
end
