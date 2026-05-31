defmodule Lux.Integrations.Telegram.GroupManagerTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Telegram.GroupManager

  @chat_id -100_123_456
  @user_id 987_654
  @message_id 42
  @message_thread_id 7

  @official_bot_api_paths MapSet.new([
                            "/approveChatJoinRequest",
                            "/banChatMember",
                            "/banChatSenderChat",
                            "/closeForumTopic",
                            "/closeGeneralForumTopic",
                            "/copyMessage",
                            "/createChatInviteLink",
                            "/createForumTopic",
                            "/declineChatJoinRequest",
                            "/deleteChatPhoto",
                            "/deleteChatStickerSet",
                            "/deleteForumTopic",
                            "/deleteMessage",
                            "/deleteMessages",
                            "/editChatInviteLink",
                            "/editForumTopic",
                            "/editGeneralForumTopic",
                            "/editMessageCaption",
                            "/editMessageText",
                            "/forwardMessage",
                            "/getChatAdministrators",
                            "/getChatMember",
                            "/getChatMemberCount",
                            "/hideGeneralForumTopic",
                            "/pinChatMessage",
                            "/promoteChatMember",
                            "/restrictChatMember",
                            "/reopenForumTopic",
                            "/reopenGeneralForumTopic",
                            "/revokeChatInviteLink",
                            "/sendMessage",
                            "/setChatAdministratorCustomTitle",
                            "/setChatDescription",
                            "/setChatMemberTag",
                            "/setChatPermissions",
                            "/setChatSlowModeDelay",
                            "/setChatStickerSet",
                            "/setChatTitle",
                            "/unbanChatMember",
                            "/unbanChatSenderChat",
                            "/unhideGeneralForumTopic",
                            "/unpinAllChatMessages",
                            "/unpinAllForumTopicMessages",
                            "/unpinAllGeneralForumTopicMessages",
                            "/unpinChatMessage"
                          ])

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "permission and admin templates" do
    test "lists known group management actions" do
      assert :moderate_message in GroupManager.known_actions()
      assert :log_admin_action in GroupManager.known_actions()
      assert :copy_channel_post in GroupManager.known_actions()
      assert :create_forum_topic in GroupManager.known_actions()
      assert :unpin_all_general_forum_topic_messages in GroupManager.known_actions()
    end

    test "advertised actions emit official Telegram Bot API paths" do
      for action <- GroupManager.known_actions() do
        assert {:ok, plan} = GroupManager.plan(action, action_params(action))
        assert plan.requests != []

        assert Enum.all?(plan.requests, fn request ->
                 MapSet.member?(@official_bot_api_paths, request.path)
               end)
      end
    end

    test "builds Telegram ChatPermissions templates with current permission flags" do
      assert {:ok, permissions} = GroupManager.permission_template(:media_limited)

      assert permissions.can_send_messages == true
      assert permissions.can_send_photos == false
      assert permissions.can_add_web_page_previews == false
      assert Map.has_key?(permissions, :can_react_to_messages)
      assert Map.has_key?(permissions, :can_edit_tag)
    end

    test "builds standard and announcement permission templates from string names" do
      assert {:ok, standard} = GroupManager.permission_template("standard")
      assert standard.can_send_messages == true
      assert standard.can_react_to_messages == true

      assert {:ok, announcement} = GroupManager.permission_template("announcement")
      assert announcement.can_send_messages == false
      assert announcement.can_react_to_messages == true
    end

    test "rejects unsupported permission templates" do
      assert {:error, "Unsupported permission template: \"unknown\""} =
               GroupManager.permission_template("unknown")

      assert {:error, "Unsupported permission template: 123"} =
               GroupManager.permission_template(123)
    end

    test "builds administrator role templates" do
      assert {:ok, rights} = GroupManager.admin_template("moderator")

      assert rights.can_manage_chat == true
      assert rights.can_delete_messages == true
      assert rights.can_restrict_members == true
      assert rights.can_post_messages == false
    end

    test "builds publisher and community manager administrator templates" do
      assert {:ok, publisher} = GroupManager.admin_template("publisher")
      assert publisher.can_post_messages == true
      assert publisher.can_edit_messages == true
      assert publisher.can_restrict_members == false

      assert {:ok, community_manager} = GroupManager.admin_template("community-manager")
      assert community_manager.can_promote_members == true
      assert community_manager.can_manage_tags == true
    end

    test "rejects unsupported administrator templates" do
      assert {:error, "Unsupported admin template: \"owner\""} =
               GroupManager.admin_template("owner")

      assert {:error, "Unsupported admin template: :owner"} =
               GroupManager.admin_template(:owner)
    end
  end

  describe "member and permission plans" do
    test "plans direct member management and lookup actions" do
      for {action, expected_path, params} <- [
            {:unban_member, "/unbanChatMember", %{user_id: @user_id, only_if_banned: true}},
            {:promote_member, "/promoteChatMember",
             %{user_id: @user_id, admin_template: "publisher"}},
            {:set_admin_title, "/setChatAdministratorCustomTitle",
             %{user_id: @user_id, custom_title: "Ops"}},
            {:unban_sender_chat, "/unbanChatSenderChat", %{sender_chat_id: -100_777_777}},
            {:get_member, "/getChatMember", %{user_id: @user_id}},
            {:get_admins, "/getChatAdministrators", %{return_bots: true}},
            {:get_member_count, "/getChatMemberCount", %{}},
            {:approve_join_request, "/approveChatJoinRequest", %{user_id: @user_id}},
            {:decline_join_request, "/declineChatJoinRequest", %{user_id: @user_id}}
          ] do
        assert {:ok, plan} = GroupManager.plan(action, Map.put(params, :chat_id, @chat_id))
        assert [%{path: ^expected_path}] = plan.requests
      end
    end

    test "plans member restrictions with named permission templates" do
      assert {:ok, plan} =
               GroupManager.plan(:restrict_member, %{
                 chat_id: @chat_id,
                 user_id: @user_id,
                 permission_template: :read_only,
                 until_date: 1_766_000_000
               })

      assert plan.category == :member_management
      assert plan.request_count == 1

      [request] = plan.requests
      assert request.method == :post
      assert request.path == "/restrictChatMember"
      assert request.payload.chat_id == @chat_id
      assert request.payload.user_id == @user_id
      assert request.payload.until_date == 1_766_000_000
      assert Enum.all?(request.payload.permissions, fn {_key, value} -> value == false end)
    end

    test "builds bot admin rights preflight metadata and blocks known-missing rights" do
      assert {:ok, required_rights} = GroupManager.required_admin_rights(:restrict_member)
      assert required_rights == [:can_restrict_members]

      assert {:ok, plan} =
               GroupManager.plan(:restrict_member, %{
                 chat_id: @chat_id,
                 user_id: @user_id,
                 bot_admin_rights: %{can_restrict_members: false}
               })

      assert plan.preflight.configured == true
      assert plan.preflight.ok == false
      assert plan.preflight.missing_rights == [:can_restrict_members]

      assert {:error, %{results: [{:error, failure}]}} = GroupManager.execute(plan)
      assert failure.request == nil
      assert failure.error =~ "Missing required Telegram admin rights: can_restrict_members"
    end

    test "plans demotion by clearing all admin rights through promoteChatMember" do
      assert {:ok, plan} =
               GroupManager.plan("demote_member", %{
                 "chat_id" => @chat_id,
                 "user_id" => @user_id
               })

      [request] = plan.requests
      assert request.path == "/promoteChatMember"
      assert request.payload.chat_id == @chat_id
      assert request.payload.user_id == @user_id
      assert request.payload.can_manage_chat == false
      assert request.payload.can_restrict_members == false
      assert request.payload.can_promote_members == false
    end

    test "normalizes nil admin flags and explicit rights maps" do
      assert {:ok, plan} =
               GroupManager.plan(:promote_member, %{
                 chat_id: @chat_id,
                 user_id: @user_id,
                 admin_rights: %{
                   "can_invite_users" => false,
                   can_manage_chat: nil,
                   can_delete_messages: true
                 }
               })

      [request] = plan.requests
      refute Map.has_key?(request.payload, :can_manage_chat)
      assert request.payload.can_delete_messages == true
      assert request.payload.can_invite_users == false
    end

    test "plans member tags and sender-chat moderation" do
      assert {:ok, tag_plan} =
               GroupManager.plan(:set_member_tag, %{
                 chat_id: @chat_id,
                 user_id: @user_id,
                 tag: "vip"
               })

      assert [%{path: "/setChatMemberTag", payload: %{tag: "vip"}}] = tag_plan.requests

      assert {:ok, sender_plan} =
               GroupManager.plan(:ban_sender_chat, %{
                 chat_id: @chat_id,
                 sender_chat_id: -100_777_777
               })

      assert [%{path: "/banChatSenderChat", payload: %{sender_chat_id: -100_777_777}}] =
               sender_plan.requests
    end

    test "plans default chat permission updates" do
      assert {:ok, plan} =
               GroupManager.plan(:set_permissions, %{
                 chat_id: @chat_id,
                 permissions: %{
                   "can_send_photos" => false,
                   can_send_messages: true,
                   can_add_web_page_previews: false
                 },
                 use_independent_chat_permissions: true
               })

      [request] = plan.requests
      assert request.path == "/setChatPermissions"
      assert request.payload.permissions.can_send_messages == true
      assert request.payload.permissions.can_send_photos == false
      assert request.payload.use_independent_chat_permissions == true
    end
  end

  describe "settings and channel post plans" do
    test "plans chat setting variants and sticker controls" do
      for {action, expected_path, params} <- [
            {"set-title", "/setChatTitle", %{title: "Lux Research"}},
            {:set_description, "/setChatDescription", %{description: ""}},
            {:delete_photo, "/deleteChatPhoto", %{}},
            {:set_slow_mode, "/setChatSlowModeDelay", %{slow_mode_delay: 0}},
            {:edit_invite_link, "/editChatInviteLink",
             %{invite_link: "https://t.me/+abc", expire_date: 1_766_000_000}},
            {:revoke_invite_link, "/revokeChatInviteLink", %{invite_link: "https://t.me/+abc"}},
            {:pin_message, "/pinChatMessage",
             %{message_id: @message_id, disable_notification: true}},
            {:unpin_message, "/unpinChatMessage", %{message_id: @message_id}},
            {:unpin_all_messages, "/unpinAllChatMessages", %{}},
            {:set_sticker_set, "/setChatStickerSet", %{sticker_set_name: "lux_stickers"}},
            {:delete_sticker_set, "/deleteChatStickerSet", %{}}
          ] do
        assert {:ok, plan} = GroupManager.plan(action, Map.put(params, :chat_id, @chat_id))
        assert [%{path: ^expected_path}] = plan.requests
      end
    end

    test "plans official forum topic operations" do
      for {action, expected_path, params} <- [
            {:create_forum_topic, "/createForumTopic",
             %{
               name: "Research",
               icon_color: 7_322_096,
               icon_custom_emoji_id: "emoji-topic"
             }},
            {:edit_forum_topic, "/editForumTopic",
             %{message_thread_id: @message_thread_id, name: "Research Q&A"}},
            {:close_forum_topic, "/closeForumTopic", %{message_thread_id: @message_thread_id}},
            {:reopen_forum_topic, "/reopenForumTopic", %{message_thread_id: @message_thread_id}},
            {:delete_forum_topic, "/deleteForumTopic", %{message_thread_id: @message_thread_id}},
            {:unpin_all_forum_topic_messages, "/unpinAllForumTopicMessages",
             %{message_thread_id: @message_thread_id}},
            {:edit_general_forum_topic, "/editGeneralForumTopic", %{name: "General Chat"}},
            {:close_general_forum_topic, "/closeGeneralForumTopic", %{}},
            {:reopen_general_forum_topic, "/reopenGeneralForumTopic", %{}},
            {:hide_general_forum_topic, "/hideGeneralForumTopic", %{}},
            {:unhide_general_forum_topic, "/unhideGeneralForumTopic", %{}},
            {:unpin_all_general_forum_topic_messages, "/unpinAllGeneralForumTopicMessages", %{}}
          ] do
        assert {:ok, plan} = GroupManager.plan(action, Map.put(params, :chat_id, @chat_id))
        assert [%{path: ^expected_path}] = plan.requests
      end
    end

    test "plans group settings and invite link operations" do
      assert {:ok, title_plan} =
               GroupManager.plan(:set_title, %{chat_id: @chat_id, title: "Lux Research"})

      assert [%{path: "/setChatTitle", payload: %{title: "Lux Research"}}] = title_plan.requests

      assert {:ok, invite_plan} =
               GroupManager.plan(:create_invite_link, %{
                 chat_id: @chat_id,
                 name: "moderator-review",
                 member_limit: 5,
                 creates_join_request: true
               })

      [invite_request] = invite_plan.requests
      assert invite_request.path == "/createChatInviteLink"
      assert invite_request.payload.name == "moderator-review"
      assert invite_request.payload.member_limit == 5
      assert invite_request.payload.creates_join_request == true
    end

    test "plans channel post create, edit, delete, forward, and copy actions" do
      for {action, expected_path, params} <- [
            {:send_channel_post, "/sendMessage", %{text: "Launch update"}},
            {:edit_channel_post, "/editMessageText", %{message_id: @message_id, text: "Updated"}},
            {:delete_channel_post, "/deleteMessage", %{message_id: @message_id}},
            {:delete_messages, "/deleteMessages", %{message_ids: [40, 41, 42]}},
            {:forward_channel_post, "/forwardMessage",
             %{from_chat_id: -100_555_555, message_id: @message_id}},
            {:copy_channel_post, "/copyMessage",
             %{from_chat_id: -100_555_555, message_id: @message_id}}
          ] do
        assert {:ok, plan} = GroupManager.plan(action, Map.put(params, :chat_id, @chat_id))
        assert [%{path: ^expected_path}] = plan.requests
      end
    end

    test "includes optional payload fields for channel post operations" do
      assert {:ok, edit_caption} =
               GroupManager.plan(:edit_channel_caption, %{
                 chat_id: @chat_id,
                 message_id: @message_id,
                 caption: "Updated caption",
                 parse_mode: "Markdown",
                 caption_entities: [%{type: "bold", offset: 0, length: 7}],
                 reply_markup: %{inline_keyboard: []}
               })

      assert [
               %{
                 path: "/editMessageCaption",
                 payload: %{
                   parse_mode: "Markdown",
                   caption_entities: [%{type: "bold", offset: 0, length: 7}],
                   reply_markup: %{inline_keyboard: []}
                 }
               }
             ] = edit_caption.requests

      assert {:ok, copy_plan} =
               GroupManager.plan(:copy_channel_post, %{
                 chat_id: @chat_id,
                 from_chat_id: -100_555_555,
                 message_id: @message_id,
                 message_thread_id: 5,
                 caption: "Copy caption",
                 protect_content: true
               })

      assert [
               %{
                 path: "/copyMessage",
                 payload: %{
                   message_thread_id: 5,
                   caption: "Copy caption",
                   protect_content: true
                 }
               }
             ] = copy_plan.requests
    end
  end

  describe "moderation and audit logging" do
    test "adds audit log delivery requests for ordinary admin actions" do
      assert {:ok, plan} =
               GroupManager.plan(:ban_member, %{
                 chat_id: @chat_id,
                 user_id: @user_id,
                 admin_id: 111,
                 reason: "raid cleanup",
                 log_chat_id: -100_999
               })

      assert plan.request_count == 2
      assert Enum.map(plan.requests, & &1.path) == ["/banChatMember", "/sendMessage"]

      [_, log_request] = plan.requests
      assert log_request.category == :admin_logging
      assert log_request.payload.chat_id == -100_999
      assert log_request.payload.text =~ "action=ban_member"
      assert log_request.payload.text =~ "reason=raid cleanup"
    end

    test "builds moderation plans with violations, action requests, and audit log requests" do
      assert {:ok, plan} =
               GroupManager.plan(:moderate_message, %{
                 chat_id: @chat_id,
                 user_id: @user_id,
                 message_id: @message_id,
                 admin_id: 111,
                 text: "FREE money at https://spam.example AAAAAAA",
                 moderation_action: :restrict_member,
                 log_chat_id: -100_999,
                 policy: %{
                   blocked_terms: ["free money"],
                   blocked_patterns: ["spam\\.example"],
                   block_links: true,
                   max_repeated_chars: 4
                 }
               })

      assert plan.status == :flagged
      assert plan.severity == :high
      assert plan.moderation_action == :restrict_member

      assert Enum.map(plan.violations, & &1.type) == [
               :blocked_term,
               :blocked_pattern,
               :link,
               :repeated_characters
             ]

      assert Enum.map(plan.requests, & &1.path) == [
               "/deleteMessage",
               "/restrictChatMember",
               "/sendMessage"
             ]

      assert plan.audit_entry.action == "moderate_message"
      assert plan.audit_entry.status == :flagged
      assert plan.audit_entry.target_user_id == @user_id
    end

    test "uses caller-supplied spam history for rate, duplicate, and link checks" do
      assert {:ok, plan} =
               GroupManager.plan(:moderate_message, %{
                 chat_id: @chat_id,
                 user_id: @user_id,
                 text: "visit https://spam.example",
                 recent_messages: [
                   %{
                     chat_id: @chat_id,
                     user_id: @user_id,
                     text: "visit https://spam.example",
                     age_seconds: 10
                   },
                   %{
                     chat_id: @chat_id,
                     user_id: @user_id,
                     text: "visit https://spam.example",
                     age_seconds: 20
                   },
                   %{
                     chat_id: @chat_id,
                     user_id: @user_id,
                     text: "old duplicate outside the window",
                     age_seconds: 120
                   },
                   %{
                     chat_id: @chat_id,
                     user_id: 999,
                     text: "visit https://spam.example",
                     age_seconds: 5
                   }
                 ],
                 policy: %{
                   max_recent_messages: 1,
                   duplicate_threshold: 2,
                   max_recent_links: 2,
                   window_seconds: 60
                 }
               })

      assert Enum.map(plan.violations, & &1.type) == [
               :message_rate,
               :duplicate_message,
               :link_history
             ]

      assert [%{recent_message_count: 2}, %{recent_duplicate_count: 2}, %{recent_link_count: 2}] =
               plan.violations
    end

    test "returns a clean moderation plan without API requests" do
      assert {:ok, plan} =
               GroupManager.plan(:moderate_message, %{
                 chat_id: @chat_id,
                 text: "Thanks for the update.",
                 policy: %{blocked_terms: ["scam"], block_links: true}
               })

      assert plan.status == :clean
      assert plan.request_count == 0
      assert plan.requests == []
      assert plan.violations == []
    end

    test "keeps non-matching patterns and disabled link checks clean" do
      assert {:ok, plan} =
               GroupManager.plan(:moderate_message, %{
                 chat_id: @chat_id,
                 text: "Plain update without a match",
                 policy: %{
                   blocked_patterns: ["spam"],
                   block_links: "not-a-boolean",
                   blocked_terms: 123
                 }
               })

      assert plan.status == :clean
      assert plan.moderation_action == :none
      assert plan.violations == []
    end

    test "uses default low severity warning moderation" do
      assert {:ok, plan} =
               GroupManager.plan(:moderate_message, %{
                 chat_id: @chat_id,
                 message_id: @message_id,
                 text: "@alpha_user @bravo_user",
                 policy: %{
                   max_mentions: 1,
                   warning_text: "Please slow down."
                 }
               })

      assert plan.severity == :low
      assert plan.moderation_action == :warn_member
      assert [%{path: "/sendMessage", payload: payload}] = plan.requests
      assert payload.text == "Please slow down."
      assert payload.reply_to_message_id == @message_id
    end

    test "uses default medium severity deletion moderation" do
      assert {:ok, plan} =
               GroupManager.plan(:moderate_message, %{
                 chat_id: @chat_id,
                 message_id: @message_id,
                 text: "This message is too long",
                 policy: %{max_length: 5}
               })

      assert plan.severity == :medium
      assert plan.moderation_action == :delete_message
      assert [%{path: "/deleteMessage", payload: %{message_id: @message_id}}] = plan.requests
      assert [%{type: :length, length: 24, max_length: 5}] = plan.violations
    end

    test "uses default high severity restriction and falls back to delete-only without user id" do
      assert {:ok, plan} =
               GroupManager.plan(:moderate_message, %{
                 chat_id: @chat_id,
                 message_id: @message_id,
                 text: "Posting too quickly",
                 recent_message_count: 5,
                 policy: %{max_recent_messages: 2}
               })

      assert plan.severity == :high
      assert plan.moderation_action == :restrict_member
      assert [%{path: "/deleteMessage"}] = plan.requests

      assert [%{type: :message_rate, recent_message_count: 5, max_recent_messages: 2}] =
               plan.violations
    end

    test "supports explicit moderation action strings and ban fallback without a user id" do
      assert {:ok, plan} =
               GroupManager.plan(:moderate_message, %{
                 chat_id: @chat_id,
                 message_id: @message_id,
                 text: "spam.example",
                 moderation_action: "ban-member",
                 policy: %{blocked_patterns: ["spam\\.example"]}
               })

      assert plan.moderation_action == :ban_member
      assert [%{path: "/deleteMessage"}] = plan.requests
    end

    test "detects uppercase moderation violations" do
      assert {:ok, plan} =
               GroupManager.plan(:moderate_message, %{
                 chat_id: @chat_id,
                 text: "LOUD ANNOUNCEMENT",
                 policy: %{min_uppercase_length: 5, uppercase_ratio: 0.8}
               })

      assert plan.severity == :low
      assert [%{type: :uppercase_ratio, severity: :low}] = plan.violations
    end

    test "rejects invalid moderation policies and non-string blocked patterns" do
      assert {:error, "policy must be a map"} =
               GroupManager.plan(:moderate_message, %{
                 chat_id: @chat_id,
                 text: "hello",
                 policy: "strict"
               })

      assert {:error, "Invalid blocked pattern 123: expected a string"} =
               GroupManager.plan(:moderate_message, %{
                 chat_id: @chat_id,
                 text: "hello",
                 policy: %{blocked_patterns: [123]}
               })
    end

    test "plans standalone admin log delivery" do
      assert {:ok, plan} =
               GroupManager.plan(:log_admin_action, %{
                 logged_action: "manual_review",
                 chat_id: @chat_id,
                 admin_id: 111,
                 user_id: @user_id,
                 message_id: @message_id,
                 reason: "Escalated for moderator review",
                 log_chat_id: -100_999
               })

      assert plan.category == :admin_logging
      assert [%{path: "/sendMessage", payload: payload}] = plan.requests
      assert payload.chat_id == -100_999
      assert payload.text =~ "action=manual_review"
      assert payload.text =~ "reason=Escalated for moderator review"
    end

    test "records admin log aliases without delivery chat" do
      assert {:ok, plan} =
               GroupManager.plan(:log_admin_action, %{
                 admin_action: "permissions_reviewed",
                 chat_id: @chat_id
               })

      assert plan.request_count == 0
      assert plan.requests == []
      assert plan.audit_entry.action == "permissions_reviewed"
      assert plan.audit_entry.status == :recorded
    end

    test "records event aliases and unknown audit actions" do
      assert {:ok, event_plan} =
               GroupManager.plan(:log_admin_action, %{event: "join_request_reviewed"})

      assert event_plan.audit_entry.action == "join_request_reviewed"

      recorded = GroupManager.audit_entry(:external_tool_action, %{}, %{})
      assert recorded.action == ":external_tool_action"
      assert recorded.status == :recorded
    end
  end

  describe "execution" do
    test "executes planned requests through the Telegram client" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path =~ "/banChatMember"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["user_id"] == @user_id
        assert decoded_body["revoke_messages"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, plan} =
               GroupManager.plan(:ban_member, %{
                 chat_id: @chat_id,
                 user_id: @user_id,
                 revoke_messages: true,
                 bot_admin_rights: %{can_restrict_members: true}
               })

      assert plan.preflight.verified == true
      assert plan.warnings == []

      assert {:ok, executed} = GroupManager.execute(plan)
      assert executed.executed == true
      assert [%{response: %{"result" => true}}] = executed.results
    end

    test "returns execution failures with request context" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{"description" => "Too Many Requests"}))
      end)

      assert {:ok, plan} =
               GroupManager.plan(:ban_member, %{
                 chat_id: @chat_id,
                 user_id: @user_id
               })

      assert {:error, %{plan: ^plan, results: [{:error, failure}]}} =
               GroupManager.execute(plan,
                 plug: {Req.Test, TelegramClientMock},
                 allow_unverified_admin_rights: true
               )

      assert failure.request.path == "/banChatMember"
      assert failure.error == {429, "Too Many Requests"}
    end
  end

  describe "admin rights safety gate" do
    test "marks destructive actions and blocks execution when rights are unverified" do
      assert {:ok, plan} =
               GroupManager.plan(:ban_member, %{chat_id: @chat_id, user_id: @user_id})

      assert plan.preflight.destructive == true
      assert plan.preflight.verified == false
      assert plan.preflight.configured == false

      assert [warning] = plan.warnings
      assert warning =~ "unverified bot admin rights"

      # No Req.Test expectation is registered: the gate must block before any
      # HTTP request is attempted.
      assert {:error, %{plan: ^plan, results: [{:error, failure}]}} = GroupManager.execute(plan)
      assert failure.request == nil
      assert failure.error =~ "Refusing to execute destructive Telegram action ban_member"
      assert failure.error =~ "without verified bot_admin_rights"
    end

    test "allows destructive execution with an explicit allow_unverified_admin_rights opt-out" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.request_path =~ "/restrictChatMember"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, plan} =
               GroupManager.plan(:restrict_member, %{
                 chat_id: @chat_id,
                 user_id: @user_id,
                 permission_template: :read_only
               })

      assert {:ok, executed} = GroupManager.execute(plan, allow_unverified_admin_rights: true)
      assert executed.executed == true
      assert [%{request: %{path: "/restrictChatMember"}}] = executed.results
    end

    test "executes destructive actions when bot_admin_rights verify the required rights" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.request_path =~ "/banChatMember"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, plan} =
               GroupManager.plan(:ban_member, %{
                 chat_id: @chat_id,
                 user_id: @user_id,
                 bot_admin_rights: %{can_restrict_members: true}
               })

      assert plan.preflight.verified == true
      assert plan.warnings == []
      assert {:ok, executed} = GroupManager.execute(plan)
      assert executed.executed == true
    end

    test "non-destructive actions execute without bot_admin_rights" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.request_path =~ "/setChatTitle"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, plan} = GroupManager.plan(:set_title, %{chat_id: @chat_id, title: "Lux"})
      assert plan.preflight.destructive == false
      assert plan.warnings == []
      assert {:ok, executed} = GroupManager.execute(plan)
      assert executed.executed == true
    end
  end

  describe "execution short-circuits on failure" do
    test "stops after the first failed request and never delivers the audit log" do
      # The plan is [deleteMessage, restrictChatMember, sendMessage(audit log)].
      # Only one HTTP call is allowed; if the executor continued past the failed
      # delete it would attempt the restrict and the audit-log send, both of
      # which would raise as unexpected Req.Test requests.
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.request_path =~ "/deleteMessage"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"description" => "Internal Server Error"}))
      end)

      assert {:ok, plan} =
               GroupManager.plan(:moderate_message, %{
                 chat_id: @chat_id,
                 user_id: @user_id,
                 message_id: @message_id,
                 text: "spam http://bad.example",
                 moderation_action: :restrict_member,
                 log_chat_id: -100_999,
                 bot_admin_rights: %{can_delete_messages: true, can_restrict_members: true},
                 policy: %{block_links: true}
               })

      assert Enum.map(plan.requests, & &1.path) == [
               "/deleteMessage",
               "/restrictChatMember",
               "/sendMessage"
             ]

      assert {:error, %{plan: ^plan, results: results}} = GroupManager.execute(plan)
      assert [{:error, failure}] = results
      assert failure.request.path == "/deleteMessage"
      assert failure.error == {500, "Internal Server Error"}
      refute Enum.any?(results, &match?({:ok, _}, &1))
    end

    test "delivers every request, including the audit log, when all succeed" do
      Req.Test.expect(TelegramClientMock, 2, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, plan} =
               GroupManager.plan(:ban_member, %{
                 chat_id: @chat_id,
                 user_id: @user_id,
                 log_chat_id: -100_999,
                 bot_admin_rights: %{can_restrict_members: true}
               })

      assert Enum.map(plan.requests, & &1.path) == ["/banChatMember", "/sendMessage"]
      assert {:ok, executed} = GroupManager.execute(plan)
      assert Enum.map(executed.results, & &1.request.path) == ["/banChatMember", "/sendMessage"]
    end
  end

  describe "sticker set capability" do
    test "warns that sticker-set actions may need the can_set_sticker_set capability" do
      for action <- [:set_sticker_set, :delete_sticker_set] do
        params =
          %{chat_id: @chat_id}
          |> Map.merge(if action == :set_sticker_set, do: %{sticker_set_name: "lux"}, else: %{})

        assert {:ok, plan} = GroupManager.plan(action, params)
        assert Enum.any?(plan.warnings, &(&1 =~ "can_set_sticker_set"))
        assert Enum.any?(plan.warnings, &(&1 =~ "getChat"))
      end
    end
  end

  describe "member management workflows" do
    test "maps add, remove, and restrict member acceptance criteria to Bot API actions" do
      # "Add" a member: invite-link / join-request approval semantics, since the
      # Telegram Bot API cannot force-add an arbitrary user to a chat.
      assert {:ok, invite_plan} =
               GroupManager.plan(:create_invite_link, %{
                 chat_id: @chat_id,
                 creates_join_request: true
               })

      assert [%{path: "/createChatInviteLink", payload: %{creates_join_request: true}}] =
               invite_plan.requests

      assert {:ok, approve_plan} =
               GroupManager.plan(:approve_join_request, %{chat_id: @chat_id, user_id: @user_id})

      assert [%{path: "/approveChatJoinRequest"}] = approve_plan.requests

      # "Remove" a member: ban / unban.
      assert {:ok, ban_plan} =
               GroupManager.plan(:ban_member, %{chat_id: @chat_id, user_id: @user_id})

      assert [%{path: "/banChatMember"}] = ban_plan.requests

      assert {:ok, unban_plan} =
               GroupManager.plan(:unban_member, %{chat_id: @chat_id, user_id: @user_id})

      assert [%{path: "/unbanChatMember"}] = unban_plan.requests

      # "Restrict" a member: restrictChatMember with a permission template.
      assert {:ok, restrict_plan} =
               GroupManager.plan(:restrict_member, %{
                 chat_id: @chat_id,
                 user_id: @user_id,
                 permission_template: :read_only
               })

      assert [%{path: "/restrictChatMember"}] = restrict_plan.requests
    end
  end

  describe "moderation performance and bulk limits" do
    test "evaluates large recent_messages windows correctly and within a generous bound" do
      recent_messages =
        for index <- 1..5_000 do
          %{
            chat_id: @chat_id,
            user_id: @user_id,
            text: "join https://spam.example",
            age_seconds: rem(index, 50)
          }
        end

      {elapsed_us, {:ok, plan}} =
        :timer.tc(fn ->
          GroupManager.plan(:moderate_message, %{
            chat_id: @chat_id,
            user_id: @user_id,
            text: "join https://spam.example",
            recent_messages: recent_messages,
            policy: %{
              max_recent_messages: 10,
              duplicate_threshold: 5,
              max_recent_links: 5,
              window_seconds: 60
            }
          })
        end)

      by_type = Map.new(plan.violations, &{&1.type, &1})

      assert by_type[:message_rate].recent_message_count == 5_000
      assert by_type[:duplicate_message].recent_duplicate_count == 5_000
      assert by_type[:link_history].recent_link_count == 5_000

      # 5k messages evaluate in well under this generous ceiling; the assertion
      # is a regression guard against accidental super-linear scanning.
      assert elapsed_us < 2_000_000
    end

    test "accepts bulk deletes at the 100-message Bot API boundary" do
      message_ids = Enum.to_list(1..100)

      assert {:ok, plan} =
               GroupManager.plan(:delete_messages, %{
                 chat_id: @chat_id,
                 message_ids: message_ids
               })

      assert [%{path: "/deleteMessages", payload: %{message_ids: ^message_ids}}] = plan.requests

      assert length(plan.requests |> hd() |> Map.fetch!(:payload) |> Map.fetch!(:message_ids)) ==
               100
    end
  end

  describe "validation" do
    test "rejects invalid required parameters and invalid patterns" do
      assert {:error, "Missing or invalid user_id"} =
               GroupManager.plan(:ban_member, %{chat_id: @chat_id})

      assert {:error, "slow_mode_delay must be between 0 and 36000"} =
               GroupManager.plan(:set_slow_mode, %{chat_id: @chat_id, slow_mode_delay: 36_001})

      assert {:error, "message_ids must contain only integers"} =
               GroupManager.plan(:delete_messages, %{chat_id: @chat_id, message_ids: [1, "2"]})

      assert {:error, message} =
               GroupManager.plan(:moderate_message, %{
                 chat_id: @chat_id,
                 text: "hello",
                 policy: %{blocked_patterns: ["["]}
               })

      assert message =~ "Invalid blocked pattern"
    end

    test "rejects invalid actions, aliases, and action types" do
      assert {:error, "Unsupported Telegram group action: :unknown"} =
               GroupManager.plan(:unknown, %{})

      assert {:error, "Unsupported Telegram group action: \"missing-action\""} =
               GroupManager.plan("missing-action", %{})

      assert {:error, "Unsupported Telegram group action: %{bad: :action}"} =
               GroupManager.plan(%{bad: :action}, %{})
    end

    test "rejects invalid chat settings and message id payloads" do
      assert {:error, "Missing or invalid chat_id"} =
               GroupManager.plan(:set_title, %{chat_id: "", title: "Lux"})

      assert {:error, "Missing or invalid chat_id"} =
               GroupManager.plan(:set_title, %{title: "Lux"})

      assert {:error, "Missing or invalid title"} =
               GroupManager.plan(:set_title, %{chat_id: @chat_id, title: ""})

      assert {:error, "Missing or invalid message_thread_id"} =
               GroupManager.plan(:close_forum_topic, %{chat_id: @chat_id})

      assert {:error, "message_ids must include between 1 and 100 message ids"} =
               GroupManager.plan(:delete_messages, %{chat_id: @chat_id, message_ids: []})

      assert {:error, "message_ids must include between 1 and 100 message ids"} =
               GroupManager.plan(:delete_messages, %{
                 chat_id: @chat_id,
                 message_ids: Enum.to_list(1..101)
               })

      assert {:error, "Missing or invalid message_ids"} =
               GroupManager.plan(:delete_messages, %{chat_id: @chat_id, message_ids: "1,2"})
    end

    test "rejects invalid permission and admin flag maps" do
      assert {:error, "permissions.can_send_messages must be a boolean"} =
               GroupManager.plan(:set_permissions, %{
                 chat_id: @chat_id,
                 permissions: %{can_send_messages: "yes"}
               })

      assert {:error, "permissions must include at least one supported flag"} =
               GroupManager.plan(:set_permissions, %{chat_id: @chat_id, permissions: %{}})

      assert {:error, "Unsupported permission template: \"locked\""} =
               GroupManager.plan(:set_permissions, %{
                 chat_id: @chat_id,
                 permission_template: "locked"
               })

      assert {:error, "admin_rights.can_manage_chat must be a boolean"} =
               GroupManager.plan(:promote_member, %{
                 chat_id: @chat_id,
                 user_id: @user_id,
                 admin_rights: %{can_manage_chat: "yes"}
               })

      assert {:error, "admin_rights must include at least one supported flag"} =
               GroupManager.plan(:promote_member, %{
                 chat_id: @chat_id,
                 user_id: @user_id,
                 admin_rights: %{}
               })

      assert {:error, "Unsupported admin template: \"owner\""} =
               GroupManager.plan(:promote_member, %{
                 chat_id: @chat_id,
                 user_id: @user_id,
                 admin_template: "owner"
               })
    end
  end

  defp action_params(action) do
    Map.merge(%{chat_id: @chat_id}, action_specific_params(action))
  end

  defp action_specific_params(action)
       when action in [:ban_member, :unban_member, :get_member] do
    %{user_id: @user_id}
  end

  defp action_specific_params(:restrict_member) do
    %{user_id: @user_id, permission_template: :read_only}
  end

  defp action_specific_params(:promote_member) do
    %{user_id: @user_id, admin_template: :moderator}
  end

  defp action_specific_params(:demote_member), do: %{user_id: @user_id}

  defp action_specific_params(:set_admin_title) do
    %{user_id: @user_id, custom_title: "Ops"}
  end

  defp action_specific_params(:set_member_tag), do: %{user_id: @user_id, tag: "vip"}

  defp action_specific_params(action) when action in [:ban_sender_chat, :unban_sender_chat] do
    %{sender_chat_id: -100_777_777}
  end

  defp action_specific_params(:set_permissions), do: %{permission_template: :standard}
  defp action_specific_params(:set_title), do: %{title: "Lux Research"}
  defp action_specific_params(:set_description), do: %{description: "Community updates"}
  defp action_specific_params(:set_slow_mode), do: %{slow_mode_delay: 0}
  defp action_specific_params(:edit_invite_link), do: %{invite_link: "https://t.me/+abc"}
  defp action_specific_params(:revoke_invite_link), do: %{invite_link: "https://t.me/+abc"}

  defp action_specific_params(action)
       when action in [:approve_join_request, :decline_join_request] do
    %{user_id: @user_id}
  end

  defp action_specific_params(action) when action in [:pin_message, :unpin_message] do
    %{message_id: @message_id}
  end

  defp action_specific_params(:set_sticker_set), do: %{sticker_set_name: "lux_stickers"}

  defp action_specific_params(:create_forum_topic) do
    %{name: "Research", icon_color: 7_322_096, icon_custom_emoji_id: "emoji-topic"}
  end

  defp action_specific_params(:edit_forum_topic) do
    %{message_thread_id: @message_thread_id, name: "Research Q&A"}
  end

  defp action_specific_params(action)
       when action in [
              :close_forum_topic,
              :reopen_forum_topic,
              :delete_forum_topic,
              :unpin_all_forum_topic_messages
            ] do
    %{message_thread_id: @message_thread_id}
  end

  defp action_specific_params(:edit_general_forum_topic), do: %{name: "General Chat"}
  defp action_specific_params(:send_channel_post), do: %{text: "Launch update"}

  defp action_specific_params(:edit_channel_post) do
    %{message_id: @message_id, text: "Updated"}
  end

  defp action_specific_params(:edit_channel_caption) do
    %{message_id: @message_id, caption: "Updated caption"}
  end

  defp action_specific_params(:delete_channel_post), do: %{message_id: @message_id}
  defp action_specific_params(:delete_messages), do: %{message_ids: [40, 41, 42]}

  defp action_specific_params(action)
       when action in [:forward_channel_post, :copy_channel_post] do
    %{from_chat_id: -100_555_555, message_id: @message_id}
  end

  defp action_specific_params(:moderate_message) do
    %{
      user_id: @user_id,
      message_id: @message_id,
      text: "spam",
      moderation_action: :restrict_member,
      policy: %{max_length: 1}
    }
  end

  defp action_specific_params(:log_admin_action) do
    %{logged_action: "manual_review", log_chat_id: -100_999}
  end

  defp action_specific_params(_action), do: %{}
end
