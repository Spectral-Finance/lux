defmodule Lux.Integrations.Telegram.GroupManagement.SettingsManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.GroupManagement.SettingsManager

  describe "SettingsManager" do
    test "set_chat_title/3 updates chat title" do
      plug = fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["chat_id"] == -100_777
        assert decoded["title"] == "Lux Community Official"

        Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      assert {:ok, _} =
               SettingsManager.set_chat_title(-100_777, "Lux Community Official", plug: plug)
    end

    test "set_slow_mode/3 updates slow mode delay" do
      plug = fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["chat_id"] == -100_777
        assert decoded["slow_mode_delay"] == 30

        Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      assert {:ok, _} =
               SettingsManager.set_slow_mode(-100_777, 30, plug: plug)
    end

    test "create_invite_link/2 creates link with membership limit" do
      plug = fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["chat_id"] == -100_777
        assert decoded["member_limit"] == 100

        res = %{
          "ok" => true,
          "result" => %{"invite_link" => "https://t.me/+AbCdEfGhIjKl", "member_limit" => 100}
        }

        Plug.Conn.send_resp(conn, 200, Jason.encode!(res))
      end

      assert {:ok, res} =
               SettingsManager.create_invite_link(-100_777,
                 member_limit: 100,
                 name: "VIP VIP",
                 plug: plug
               )

      assert res["result"]["invite_link"] == "https://t.me/+AbCdEfGhIjKl"
    end

    test "approve_join_request/3 approves user join" do
      plug = fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["user_id"] == 12345

        Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      assert {:ok, _} = SettingsManager.approve_join_request(-100_777, 12345, plug: plug)
    end
  end
end
