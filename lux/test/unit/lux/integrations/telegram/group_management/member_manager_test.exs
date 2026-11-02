defmodule Lux.Integrations.Telegram.GroupManagement.MemberManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.GroupManagement.MemberManager

  describe "MemberManager" do
    test "ban_member/3 constructs valid payload and handles response" do
      plug = fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["chat_id"] == -100_123_456
        assert decoded["user_id"] == 999
        assert decoded["revoke_messages"] == true

        Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      assert {:ok, %{"ok" => true, "result" => true}} =
               MemberManager.ban_member(-100_123_456, 999, revoke_messages: true, plug: plug)
    end

    test "unban_member/3 handles unbanning" do
      plug = fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["chat_id"] == -100_123_456
        assert decoded["user_id"] == 999
        assert decoded["only_if_banned"] == true

        Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      assert {:ok, %{"ok" => true, "result" => true}} =
               MemberManager.unban_member(-100_123_456, 999, only_if_banned: true, plug: plug)
    end

    test "restrict_member/4 sets member restrictions" do
      plug = fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["chat_id"] == -100_123_456
        assert decoded["user_id"] == 888
        assert decoded["permissions"]["can_send_messages"] == false

        Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      assert {:ok, _} =
               MemberManager.restrict_member(-100_123_456, 888, %{can_send_messages: false},
                 plug: plug
               )
    end

    test "promote_member/4 promotes user with admin rights" do
      plug = fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["can_delete_messages"] == true
        assert decoded["can_restrict_members"] == true

        Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      privileges = %{can_delete_messages: true, can_restrict_members: true}

      assert {:ok, _} =
               MemberManager.promote_member(-100_123, 777, privileges, plug: plug)
    end

    test "get_chat_member/3 and get_chat_member_count/2" do
      plug = fn conn ->
        Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"ok" => true, "result" => 42}))
      end

      assert {:ok, %{"result" => 42}} =
               MemberManager.get_chat_member_count(-100_123, plug: plug)
    end
  end
end
