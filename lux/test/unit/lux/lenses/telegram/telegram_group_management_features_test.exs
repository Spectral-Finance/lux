defmodule Lux.Lenses.TelegramGroupManagementFeaturesTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.TelegramGroupManagementFeatures

  setup do
    Req.Test.verify_on_exit!()

    # Set up test token
    original_config = Application.get_env(:lux, :api_keys)

    on_exit(fn ->
      Application.put_env(:lux, :api_keys, original_config)
    end)

    # Set both telegram_bot and integration_telegram_bot keys
    Application.put_env(:lux, :api_keys, [
      telegram_bot: "test_token",
      integration_telegram_bot: "test_integration_token"
    ])

    :ok
  end

  describe "Member Management" do
    test "ban_chat_member/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "banChatMember")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["user_id"] == 987_654_321
        assert body["until_date"] == 1_735_689_600  # Optional parameter

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      assert {:ok, true} =
        TelegramGroupManagementFeatures.ban_chat_member(
          "123456789",
          987_654_321,
          %{until_date: 1_735_689_600}
        )
    end

    test "unban_chat_member/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "unbanChatMember")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["user_id"] == 987_654_321
        assert body["only_if_banned"] == true  # Optional parameter

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      assert {:ok, true} =
        TelegramGroupManagementFeatures.unban_chat_member(
          "123456789",
          987_654_321,
          %{only_if_banned: true}
        )
    end

    test "restrict_chat_member/4" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "restrictChatMember")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["user_id"] == 987_654_321
        assert body["permissions"]["can_send_messages"] == false
        assert body["permissions"]["can_send_media_messages"] == false
        assert body["until_date"] == 1_735_689_600  # Optional parameter

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      permissions = %{
        can_send_messages: false,
        can_send_media_messages: false
      }

      assert {:ok, true} =
        TelegramGroupManagementFeatures.restrict_chat_member(
          "123456789",
          987_654_321,
          permissions,
          %{until_date: 1_735_689_600}
        )
    end

    test "promote_chat_member/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "promoteChatMember")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["user_id"] == 987_654_321
        assert body["can_delete_messages"] == true
        assert body["can_restrict_members"] == true

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      assert {:ok, true} =
        TelegramGroupManagementFeatures.promote_chat_member(
          "123456789",
          987_654_321,
          %{
            can_delete_messages: true,
            can_restrict_members: true
          }
        )
    end

    test "set_chat_administrator_custom_title/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "setChatAdministratorCustomTitle")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["user_id"] == 987_654_321
        assert body["custom_title"] == "Group Moderator"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      assert {:ok, true} =
        TelegramGroupManagementFeatures.set_chat_administrator_custom_title(
          "123456789",
          987_654_321,
          "Group Moderator"
        )
    end

    test "ban_chat_sender_chat/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "banChatSenderChat")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["sender_chat_id"] == "-100_987_654_321"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      assert {:ok, true} =
        TelegramGroupManagementFeatures.ban_chat_sender_chat(
          "123456789",
          "-100_987_654_321"
        )
    end

    test "unban_chat_sender_chat/2" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "unbanChatSenderChat")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["sender_chat_id"] == "-100_987_654_321"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      assert {:ok, true} =
        TelegramGroupManagementFeatures.unban_chat_sender_chat(
          "123456789",
          "-100_987_654_321"
        )
    end
  end

  describe "Permission Management" do
    test "set_chat_permissions/2" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "setChatPermissions")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["permissions"]["can_send_messages"] == true
        assert body["permissions"]["can_send_media_messages"] == true
        assert body["permissions"]["can_send_polls"] == false

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      permissions = %{
        can_send_messages: true,
        can_send_media_messages: true,
        can_send_polls: false
      }

      assert {:ok, true} =
        TelegramGroupManagementFeatures.set_chat_permissions(
          "123456789",
          permissions
        )
    end

    test "create_chat_invite_link/2" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "createChatInviteLink")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["name"] == "Special Invite"
        assert body["expire_date"] == 1_735_689_600
        assert body["member_limit"] == 10

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "invite_link" => "https://t.me/joinchat/AAAAAAAAAAAAAAAAAAAA",
            "creator" => %{"id" => 12_345, "is_bot" => true, "first_name" => "Bot"},
            "name" => "Special Invite",
            "expire_date" => 1_735_689_600,
            "member_limit" => 10,
            "creates_join_request" => false
          }
        })
      end)

      assert {:ok, %{"invite_link" => "https://t.me/joinchat/AAAAAAAAAAAAAAAAAAAA"}} =
        TelegramGroupManagementFeatures.create_chat_invite_link(
          "123456789",
          %{
            name: "Special Invite",
            expire_date: 1_735_689_600,
            member_limit: 10
          }
        )
    end

    test "edit_chat_invite_link/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "editChatInviteLink")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["invite_link"] == "https://t.me/joinchat/AAAAAAAAAAAAAAAAAAAA"
        assert body["name"] == "Updated Invite"
        assert body["expire_date"] == 1_735_689_600

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "invite_link" => "https://t.me/joinchat/AAAAAAAAAAAAAAAAAAAA",
            "creator" => %{"id" => 12_345, "is_bot" => true, "first_name" => "Bot"},
            "name" => "Updated Invite",
            "expire_date" => 1_735_689_600,
            "member_limit" => 10,
            "creates_join_request" => false
          }
        })
      end)

      assert {:ok, %{"name" => "Updated Invite"}} =
        TelegramGroupManagementFeatures.edit_chat_invite_link(
          "123456789",
          "https://t.me/joinchat/AAAAAAAAAAAAAAAAAAAA",
          %{
            name: "Updated Invite",
            expire_date: 1_735_689_600
          }
        )
    end

    test "revoke_chat_invite_link/2" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "revokeChatInviteLink")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["invite_link"] == "https://t.me/joinchat/AAAAAAAAAAAAAAAAAAAA"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "invite_link" => "https://t.me/joinchat/AAAAAAAAAAAAAAAAAAAA",
            "creator" => %{"id" => 12_345, "is_bot" => true, "first_name" => "Bot"},
            "is_revoked" => true
          }
        })
      end)

      assert {:ok, %{"is_revoked" => true}} =
        TelegramGroupManagementFeatures.revoke_chat_invite_link(
          "123456789",
          "https://t.me/joinchat/AAAAAAAAAAAAAAAAAAAA"
        )
    end

    test "approve_chat_join_request/2" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "approveChatJoinRequest")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["user_id"] == 987_654_321

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      assert {:ok, true} =
        TelegramGroupManagementFeatures.approve_chat_join_request(
          "123456789",
          987_654_321
        )
    end

    test "decline_chat_join_request/2" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "declineChatJoinRequest")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["user_id"] == 987_654_321

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      assert {:ok, true} =
        TelegramGroupManagementFeatures.decline_chat_join_request(
          "123456789",
          987_654_321
        )
    end
  end

  describe "Content Moderation" do
    test "delete_message/2" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "deleteMessage")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["message_id"] == 42

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      assert {:ok, true} =
        TelegramGroupManagementFeatures.delete_message(
          "123456789",
          42
        )
    end

    test "delete_messages/2" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "deleteMessages")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["message_ids"] == [41, 42, 43]

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      assert {:ok, true} =
        TelegramGroupManagementFeatures.delete_messages(
          "123456789",
          [41, 42, 43]
        )
    end

    test "delete_chat_photo/1" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "deleteChatPhoto")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      assert {:ok, true} =
        TelegramGroupManagementFeatures.delete_chat_photo("123456789")
    end

    test "clean_chat_history/2" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "cleanChatHistory")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["for_everyone"] == true

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      assert {:ok, true} =
        TelegramGroupManagementFeatures.clean_chat_history(
          "123456789",
          %{for_everyone: true}
        )
    end
  end

  describe "Spam Protection" do
    test "set_chat_slow_mode_delay/2" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "setChatSlowModeDelay")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["seconds"] == 30

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      assert {:ok, true} =
        TelegramGroupManagementFeatures.set_chat_slow_mode_delay(
          "123456789",
          30
        )
    end
  end

  describe "Group Settings Management" do
    test "set_chat_title/2" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "setChatTitle")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["title"] == "New Group Title"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      assert {:ok, true} =
        TelegramGroupManagementFeatures.set_chat_title(
          "123456789",
          "New Group Title"
        )
    end

    test "set_chat_description/2" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "setChatDescription")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["description"] == "New group description"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      assert {:ok, true} =
        TelegramGroupManagementFeatures.set_chat_description(
          "123456789",
          "New group description"
        )
    end

    test "set_chat_photo/2" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "setChatPhoto")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["photo"] == "photo_file_id"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      assert {:ok, true} =
        TelegramGroupManagementFeatures.set_chat_photo(
          "123456789",
          "photo_file_id"
        )
    end

    test "pin_chat_message/3" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "pinChatMessage")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["message_id"] == 42
        assert body["disable_notification"] == true

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      assert {:ok, true} =
        TelegramGroupManagementFeatures.pin_chat_message(
          "123456789",
          42,
          %{disable_notification: true}
        )
    end

    test "unpin_chat_message/2" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "unpinChatMessage")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["message_id"] == 42

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      assert {:ok, true} =
        TelegramGroupManagementFeatures.unpin_chat_message(
          "123456789",
          42
        )
    end

    test "unpin_all_chat_messages/1" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "unpinAllChatMessages")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      assert {:ok, true} =
        TelegramGroupManagementFeatures.unpin_all_chat_messages("123456789")
    end
  end

  describe "Channel Post Management" do
    test "edit_channel_post/4" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "editMessageText")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["message_id"] == 42
        assert body["text"] == "Updated post text"
        assert body["parse_mode"] == "Markdown"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 42,
            "from" => %{"id" => 12_345, "is_bot" => true, "first_name" => "Bot"},
            "chat" => %{"id" => 123_456_789, "type" => "channel"},
            "date" => 1_609_459_200,
            "text" => "Updated post text",
            "entities" => []
          }
        })
      end)

      assert {:ok, %{"message_id" => 42, "text" => "Updated post text"}} =
        TelegramGroupManagementFeatures.edit_channel_post(
          "123456789",
          42,
          "Updated post text",
          %{parse_mode: "Markdown"}
        )
    end

    test "edit_channel_post_caption/4" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "editMessageCaption")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["message_id"] == 42
        assert body["caption"] == "Updated caption"
        assert body["parse_mode"] == "Markdown"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => %{
            "message_id" => 42,
            "from" => %{"id" => 12_345, "is_bot" => true, "first_name" => "Bot"},
            "chat" => %{"id" => 123_456_789, "type" => "channel"},
            "date" => 1_609_459_200,
            "photo" => [%{"file_id" => "photo_file_id"}],
            "caption" => "Updated caption"
          }
        })
      end)

      assert {:ok, %{"message_id" => 42, "caption" => "Updated caption"}} =
        TelegramGroupManagementFeatures.edit_channel_post_caption(
          "123456789",
          42,
          "Updated caption",
          %{parse_mode: "Markdown"}
        )
    end

    test "delete_channel_post/2" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "deleteMessage")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"
        assert body["message_id"] == 42

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      assert {:ok, true} =
        TelegramGroupManagementFeatures.delete_channel_post(
          "123456789",
          42
        )
    end
  end

  describe "Utility Functions" do
    test "get_chat_administrators/1" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "getChatAdministrators")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => [
            %{
              "user" => %{"id" => 12_345, "is_bot" => false, "first_name" => "Admin"},
              "status" => "creator",
              "is_anonymous" => false
            },
            %{
              "user" => %{"id" => 67_890, "is_bot" => true, "first_name" => "Bot"},
              "status" => "administrator",
              "can_delete_messages" => true,
              "can_restrict_members" => true
            }
          ]
        })
      end)

      assert {:ok, admins} = TelegramGroupManagementFeatures.get_chat_administrators("123456789")
      assert length(admins) == 2
      assert hd(admins)["status"] == "creator"
    end

    test "export_chat_invite_link/1" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "exportChatInviteLink")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => "https://t.me/joinchat/AAAAAAAAAAAAAAAAAAAA"
        })
      end)

      assert {:ok, "https://t.me/joinchat/AAAAAAAAAAAAAAAAAAAA"} =
        TelegramGroupManagementFeatures.export_chat_invite_link("123456789")
    end

    test "leave_chat/1" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "leaveChat")

        body = Jason.decode!(conn.adapter |> elem(1) |> Map.get(:req_body))
        assert body["chat_id"] == "123456789"

        Req.Test.json(conn, %{
          "ok" => true,
          "result" => true
        })
      end)

      assert {:ok, true} = TelegramGroupManagementFeatures.leave_chat("123456789")
    end
  end
end
