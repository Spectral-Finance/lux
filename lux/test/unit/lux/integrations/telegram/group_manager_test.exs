defmodule Lux.Integrations.Telegram.GroupManagerTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Telegram.GroupManager

  describe "member_permissions/2" do
    test "builds named permission templates with boolean overrides" do
      assert {:ok, permissions} =
               GroupManager.member_permissions(:read_only, %{
                 "can_invite_users" => true,
                 can_send_messages: true,
                 ignored_value: true
               })

      assert permissions.can_send_messages == true
      assert permissions.can_send_photos == false
      assert permissions.can_invite_users == true
      refute Map.has_key?(permissions, :ignored_value)
    end

    test "rejects unknown permission templates" do
      assert GroupManager.member_permissions(:unknown) ==
               {:error, "Unknown Telegram permission template: unknown"}
    end
  end

  describe "admin_permissions/2" do
    test "builds moderator admin permissions" do
      assert {:ok, permissions} = GroupManager.admin_permissions(:moderator)

      assert permissions.can_manage_chat == true
      assert permissions.can_delete_messages == true
      assert permissions.can_promote_members == false
    end
  end

  describe "moderation action plans" do
    test "builds restrict member plans with permissions and until date" do
      assert {:ok, action} =
               GroupManager.restrict_member(-1001, 42, :read_only, %{
                 until_date: 1_800_000_000,
                 use_independent_chat_permissions: true
               })

      assert action.method == :post
      assert action.endpoint == "/restrictChatMember"
      assert action.payload.chat_id == -1001
      assert action.payload.user_id == 42
      assert action.payload.until_date == 1_800_000_000
      assert action.payload.permissions.can_send_messages == false
      assert action.payload.use_independent_chat_permissions == true
    end

    test "builds ban and unban member plans" do
      assert {:ok, ban} = GroupManager.ban_member("@group", 42, %{revoke_messages: true})
      assert ban.endpoint == "/banChatMember"
      assert ban.payload.revoke_messages == true

      assert {:ok, unban} = GroupManager.unban_member("@group", 42, %{only_if_banned: true})
      assert unban.endpoint == "/unbanChatMember"
      assert unban.payload.only_if_banned == true
    end
  end

  describe "permission and admin action plans" do
    test "builds promote member plans from admin templates" do
      assert {:ok, action} =
               GroupManager.promote_member("@channel", 42, :publisher, %{
                 custom_title: "Publisher"
               })

      assert action.endpoint == "/promoteChatMember"
      assert action.payload.can_post_messages == true
      assert action.payload.can_edit_messages == true
      assert action.payload.custom_title == "Publisher"
    end

    test "builds default chat permission plans" do
      assert {:ok, action} = GroupManager.set_chat_permissions(-1001, :media_allowed)

      assert action.endpoint == "/setChatPermissions"
      assert action.payload.permissions.can_send_messages == true
      assert action.payload.permissions.can_send_other_messages == false
    end
  end

  describe "channel_post/3" do
    test "builds sendMessage plans for channel posts" do
      assert {:ok, action} =
               GroupManager.channel_post("@channel", "release notes", %{
                 parse_mode: "MarkdownV2",
                 disable_notification: true,
                 message_thread_id: 7
               })

      assert action.endpoint == "/sendMessage"
      assert action.payload.text == "release notes"
      assert action.payload.parse_mode == "MarkdownV2"
      assert action.payload.disable_notification == true
      assert action.payload.message_thread_id == 7
    end
  end

  describe "admin_log_entry/2" do
    test "creates stable audit log entries" do
      occurred_at = ~U[2026-05-13 00:00:00Z]

      entry =
        GroupManager.admin_log_entry(:restrict_member, %{
          actor_id: 1,
          target_user_id: 42,
          chat_id: -1001,
          reason: "spam burst",
          metadata: %{duration: 3600},
          occurred_at: occurred_at
        })

      assert entry.action == :restrict_member
      assert entry.actor_id == 1
      assert entry.target_user_id == 42
      assert entry.reason == "spam burst"
      assert entry.metadata.duration == 3600
      assert entry.occurred_at == occurred_at
    end
  end
end
