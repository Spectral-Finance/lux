defmodule Lux.Integrations.Telegram.GroupManagerTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Telegram.GroupManager

  @chat_id -100_123
  @user_id 42
  @now "2026-05-14T02:20:00Z"

  describe "permission templates" do
    test "builds group, restricted, admin, and role permission systems" do
      assert {:ok, default} = GroupManager.permission_template(:default)
      assert default.can_send_messages
      assert default.can_invite_users

      assert {:ok, media_limited} = GroupManager.permission_template(:media_limited)
      assert media_limited.can_send_messages
      refute media_limited.can_send_photos
      refute media_limited.can_add_web_page_previews

      assert {:ok, moderator} = GroupManager.permission_template(:moderator)
      assert moderator.can_delete_messages
      assert moderator.can_restrict_members

      assert {:ok, system} = GroupManager.permission_system(%{chat_id: @chat_id, now: @now})
      assert system.roles.member.chat_permissions.can_send_messages
      assert system.roles.channel_publisher.admin_permissions.can_post_messages
      assert system.generated_at == @now
    end
  end

  describe "member action plans" do
    test "plans restrict, promote, and invite actions" do
      assert {:ok, restrict} =
               GroupManager.member_action_plan(%{
                 action: :restrict,
                 chat_id: @chat_id,
                 user_id: @user_id,
                 permissions: :read_only,
                 until_date: 1_800_000_000,
                 actor_id: "admin-1",
                 now: @now
               })

      assert restrict.category == :member_management
      assert restrict.request.method == "restrictChatMember"
      assert restrict.request.payload.permissions.can_send_messages == false
      assert restrict.audit.actor_id == "admin-1"

      assert {:ok, promote} =
               GroupManager.member_action_plan(%{
                 action: "promote",
                 chat_id: @chat_id,
                 user_id: @user_id,
                 permissions: :moderator
               })

      assert promote.request.method == "promoteChatMember"
      assert promote.request.payload.can_delete_messages

      assert {:ok, invite} =
               GroupManager.member_action_plan(%{
                 action: :invite,
                 chat_id: @chat_id,
                 user_id: @user_id,
                 name: "support invite"
               })

      assert invite.request.method == "createChatInviteLink"
      assert invite.request.payload.member_limit == 1
    end
  end

  describe "moderation and spam protection" do
    test "detects blocked content and builds moderation requests with an audit entry" do
      message = %{
        chat_id: @chat_id,
        message_id: 99,
        user_id: @user_id,
        text: "FREE AIRDROP http://spam.example @one @two @three @four @five @six"
      }

      assert {:ok, plan} =
               GroupManager.moderation_action_plan(%{
                 actor_id: "bot",
                 message: message,
                 rules: %{
                   blocked_words: ["airdrop"],
                   allow_links: false,
                   mention_limit: 5,
                   high_action: :restrict,
                   now: @now
                 },
                 now: @now
               })

      assert plan.action == :restrict
      assert plan.moderation.severity == :high
      assert :blocked_word in plan.moderation.findings
      assert Enum.any?(plan.moderation.requests, &(&1.method == "deleteMessage"))
      assert Enum.any?(plan.moderation.requests, &(&1.method == "restrictChatMember"))
      assert plan.audit.request_count == 2
    end

    test "detects duplicate and burst spam" do
      events =
        for id <- 1..5 do
          %{message_id: id, user_id: @user_id, text: "same promo"}
        end

      assert {:ok, result} =
               GroupManager.spam_protection(events, %{
                 duplicate_threshold: 3,
                 burst_threshold: 5,
                 now: @now
               })

      assert Enum.any?(result.flags, &match?(%{type: :duplicate_text, count: 5}, &1))
      assert %{type: :message_burst, user_id: @user_id, count: 5} in result.flags
      assert result.evaluated_at == @now
    end
  end

  describe "settings, posts, and audit" do
    test "plans group settings and channel posts" do
      assert {:ok, settings} =
               GroupManager.group_settings_plan(%{
                 action: :permissions,
                 chat_id: @chat_id,
                 permissions: :no_links
               })

      assert settings.request.method == "setChatPermissions"
      refute settings.request.payload.permissions.can_add_web_page_previews

      assert {:ok, post} =
               GroupManager.channel_post_plan(%{
                 action: :send,
                 chat_id: "@lux_updates",
                 text: "Weekly update",
                 protect_content: true
               })

      assert post.request.method == "sendMessage"
      assert post.request.payload.protect_content
    end

    test "filters and summarizes admin audit entries" do
      entries = [
        GroupManager.audit_log_entry(%{
          action: :ban,
          actor_id: "admin-1",
          chat_id: @chat_id,
          target_user_id: 1,
          now: @now
        }),
        GroupManager.audit_log_entry(%{
          action: :restrict,
          actor_id: "admin-2",
          chat_id: @chat_id,
          target_user_id: 2,
          now: @now
        })
      ]

      assert {:ok, audit} = GroupManager.audit_log(entries, %{chat_id: @chat_id})

      assert audit.count == 2
      assert audit.actions.ban == 1
      assert audit.actors["admin-1"] == 1
    end
  end
end
