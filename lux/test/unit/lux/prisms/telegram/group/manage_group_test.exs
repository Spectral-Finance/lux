defmodule Lux.Prisms.Telegram.Group.ManageGroupTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Telegram.GroupManager
  alias Lux.Prisms.Telegram.Group.ManageGroup

  @chat_id -100_123_456
  @user_id 987_654
  @agent_ctx %{name: "ModerationAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "returns a dry-run plan by default" do
      assert {:ok, result} =
               ManageGroup.handler(
                 %{
                   action: "restrict_member",
                   chat_id: @chat_id,
                   user_id: @user_id,
                   permission_template: "read_only"
                 },
                 @agent_ctx
               )

      assert result.planned == true
      assert result.executed == false
      assert result.action == "restrict_member"
      assert result.category == "member_management"
      assert result.preflight.required_rights == ["can_restrict_members"]
      assert [%{path: "/restrictChatMember"}] = result.requests
    end

    test "executes a planned Telegram request when execute is true" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path =~ "/setChatPermissions"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["permissions"]["can_send_messages"] == true
        assert decoded_body["permissions"]["can_add_web_page_previews"] == false

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, result} =
               ManageGroup.handler(
                 %{
                   action: :set_permissions,
                   chat_id: @chat_id,
                   permission_template: :no_links,
                   bot_admin_rights: %{can_restrict_members: true},
                   execute: true
                 },
                 @agent_ctx
               )

      assert result.planned == true
      assert result.executed == true
      assert result.request_count == 1
      assert result.action == "set_permissions"
      assert result.category == "permission_management"
      assert [%{response: %{"result" => true}}] = result.results
    end

    test "executes with string truthy values and ignores nil execution options" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path =~ "/unbanChatMember"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["only_if_banned"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, result} =
               ManageGroup.handler(
                 %{
                   action: "unban_member",
                   chat_id: @chat_id,
                   user_id: @user_id,
                   only_if_banned: true,
                   allow_unverified_admin_rights: true,
                   execute: "1",
                   plug: nil
                 },
                 @agent_ctx
               )

      assert result.executed == true
      assert [%{request: %{path: "/unbanChatMember"}}] = result.results
    end

    test "returns execution errors from the Telegram client" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.request_path =~ "/banChatMember"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"description" => "Forbidden"}))
      end)

      assert {:error, message} =
               ManageGroup.handler(
                 %{
                   action: :ban_member,
                   chat_id: @chat_id,
                   user_id: @user_id,
                   execute: true,
                   token: "test-token",
                   allow_unverified_admin_rights: true
                 },
                 @agent_ctx
               )

      assert message =~ "Failed to execute Telegram group action"
      assert message =~ "Forbidden"
    end

    test "builds moderation plans for flagged content" do
      assert {:ok, result} =
               ManageGroup.handler(
                 %{
                   action: :moderate_message,
                   chat_id: @chat_id,
                   user_id: @user_id,
                   message_id: 55,
                   text: "Join https://spam.example now",
                   policy: %{block_links: true},
                   moderation_action: :ban_member
                 },
                 @agent_ctx
               )

      assert result.status == "flagged"
      assert result.moderation_action == "ban_member"
      assert Enum.map(result.requests, & &1.path) == ["/deleteMessage", "/banChatMember"]
    end

    test "validates required action and parameters" do
      assert {:error, "Missing or invalid action"} = ManageGroup.handler(%{}, @agent_ctx)
      assert {:error, "Missing or invalid action"} = ManageGroup.handler(nil, @agent_ctx)

      assert {:error, "Missing or invalid user_id"} =
               ManageGroup.handler(%{action: :ban_member, chat_id: @chat_id}, @agent_ctx)
    end
  end

  describe "schema validation" do
    test "advertises group management actions and execution controls" do
      prism = ManageGroup.view()

      assert prism.input_schema.required == ["action"]
      assert "ban_member" in prism.input_schema.properties.action.enum
      assert "create_forum_topic" in prism.input_schema.properties.action.enum
      assert "unpin_all_general_forum_topic_messages" in prism.input_schema.properties.action.enum
      assert "moderate_message" in prism.input_schema.properties.action.enum
      assert "log_admin_action" in prism.input_schema.properties.action.enum
      assert Map.has_key?(prism.input_schema.properties, :message_thread_id)
      assert Map.has_key?(prism.input_schema.properties, :icon_custom_emoji_id)
      assert Map.has_key?(prism.input_schema.properties, :execute)
      assert Map.has_key?(prism.input_schema.properties, :recent_messages)
      assert Map.has_key?(prism.input_schema.properties, :bot_admin_rights)
      assert Map.has_key?(prism.input_schema.properties, :token)
      assert Map.has_key?(prism.input_schema.properties, :allow_unverified_admin_rights)
      assert Map.has_key?(prism.output_schema.properties, :requests)
      assert Map.has_key?(prism.output_schema.properties, :audit_entry)

      # Every field produced by normalize_output/1 must be advertised so agents
      # can rely on the documented contract for moderation and execution output.
      for field <- [
            :status,
            :severity,
            :moderation_action,
            :violations,
            :preflight,
            :warnings,
            :results
          ] do
        assert Map.has_key?(prism.output_schema.properties, field),
               "output_schema is missing advertised field #{inspect(field)}"
      end

      assert MapSet.new(prism.input_schema.properties.action.enum) ==
               MapSet.new(Enum.map(GroupManager.known_actions(), &Atom.to_string/1))
    end
  end

  describe "preflight and execution safety" do
    test "dry-run output surfaces the preflight summary and unverified-rights warning" do
      assert {:ok, result} =
               ManageGroup.handler(
                 %{action: :ban_member, chat_id: @chat_id, user_id: @user_id},
                 @agent_ctx
               )

      assert result.executed == false
      assert result.preflight.action == "ban_member"
      assert result.preflight.required_rights == ["can_restrict_members"]
      assert result.preflight.destructive == true
      assert result.preflight.verified == false
      assert [warning] = result.warnings
      assert warning =~ "unverified bot admin rights"
    end

    test "blocks destructive execution without verified rights or an explicit opt-out" do
      # No Req.Test expectation: the safety gate must reject before any request.
      assert {:error, message} =
               ManageGroup.handler(
                 %{action: :ban_member, chat_id: @chat_id, user_id: @user_id, execute: true},
                 @agent_ctx
               )

      assert message =~ "Failed to execute Telegram group action"
      assert message =~ "without verified bot_admin_rights"
    end
  end
end
