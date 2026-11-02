defmodule Lux.Integrations.Telegram.GroupManagement.ChannelPostManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.GroupManagement.ChannelPostManager

  describe "ChannelPostManager" do
    test "pin_message/3 pins message silently" do
      plug = fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["chat_id"] == -100_555
        assert decoded["message_id"] == 999
        assert decoded["disable_notification"] == true

        Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      assert {:ok, _} =
               ChannelPostManager.pin_message(-100_555, 999,
                 disable_notification: true,
                 plug: plug
               )
    end

    test "unpin_message/2 unpins message" do
      plug = fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["message_id"] == 999

        Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      assert {:ok, _} =
               ChannelPostManager.unpin_message(-100_555, message_id: 999, plug: plug)
    end

    test "unpin_all_messages/2 clears pinned list" do
      plug = fn conn ->
        Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      assert {:ok, _} = ChannelPostManager.unpin_all_messages(-100_555, plug: plug)
    end
  end
end
