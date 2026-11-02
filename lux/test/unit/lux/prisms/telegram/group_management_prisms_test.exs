defmodule Lux.Prisms.Telegram.GroupManagementPrismsTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Telegram.GroupManagement.{
    BanMember,
    UnbanMember,
    RestrictMember,
    PromoteMember,
    SetChatPermissions,
    ModerateContent,
    ManageInviteLink,
    ManagePinnedMessage,
    LogAdminAction
  }

  describe "GroupManagement Prisms" do
    test "BanMember prism bans user" do
      plug = fn conn ->
        Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      params = %{chat_id: -100_123, user_id: 456, revoke_messages: true, plug: plug}
      assert {:ok, result} = BanMember.handler(params, %{})
      assert result.status == "banned"
      assert result.user_id == 456
    end

    test "UnbanMember prism unbans user" do
      plug = fn conn ->
        Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      params = %{chat_id: -100_123, user_id: 456, plug: plug}
      assert {:ok, result} = UnbanMember.handler(params, %{})
      assert result.status == "unbanned"
    end

    test "RestrictMember prism restricts permissions" do
      plug = fn conn ->
        Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      params = %{chat_id: -100_123, user_id: 456, preset: "read_only", plug: plug}
      assert {:ok, result} = RestrictMember.handler(params, %{})
      assert result.status == "restricted"
      assert result.permissions.can_send_messages == false
    end

    test "PromoteMember prism promotes administrator" do
      plug = fn conn ->
        Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      params = %{
        chat_id: -100_123,
        user_id: 456,
        privileges: %{can_delete_messages: true},
        plug: plug
      }

      assert {:ok, result} = PromoteMember.handler(params, %{})
      assert result.status == "promoted"
    end

    test "SetChatPermissions prism updates default group permissions" do
      plug = fn conn ->
        Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      params = %{chat_id: -100_123, preset: "text_only", plug: plug}
      assert {:ok, result} = SetChatPermissions.handler(params, %{})
      assert result.status == "updated"
      assert result.permissions.can_send_messages == true
    end

    test "ModerateContent prism detects violations" do
      msg = %{
        chat_id: -100_123,
        message_id: 50,
        text: "Special airdrop claim at free crypto"
      }

      assert {:ok, result} = ModerateContent.handler(%{message: msg}, %{})
      assert result.violation == "banned_word"
      assert result.action == "delete_and_warn"
      assert result.executed == false
    end

    test "ManageInviteLink prism creates invite link" do
      plug = fn conn ->
        res = %{
          "ok" => true,
          "result" => %{"invite_link" => "https://t.me/+join_test"}
        }

        Plug.Conn.send_resp(conn, 200, Jason.encode!(res))
      end

      params = %{action: "create", chat_id: -100_123, member_limit: 50, plug: plug}
      assert {:ok, result} = ManageInviteLink.handler(params, %{})
      assert result.status == "created"
      assert result.invite_link == "https://t.me/+join_test"
    end

    test "ManagePinnedMessage prism pins message" do
      plug = fn conn ->
        Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      params = %{action: "pin", chat_id: -100_123, message_id: 777, plug: plug}
      assert {:ok, result} = ManagePinnedMessage.handler(params, %{})
      assert result.status == "pinned"
      assert result.message_id == 777
    end

    test "LogAdminAction prism formats audit notification" do
      params = %{
        action: "ban",
        chat_id: -100_123,
        target_id: 888,
        actor_id: 999,
        reason: "Phishing links"
      }

      assert {:ok, result} = LogAdminAction.handler(params, %{})
      assert result.action == "ban"
      assert String.contains?(result.formatted_html, "AUDIT LOG - BAN")
      assert String.contains?(result.formatted_markdown, "Phishing links")
    end
  end
end
