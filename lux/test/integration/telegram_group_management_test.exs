defmodule Lux.Integration.TelegramGroupManagementTest do
  use IntegrationCase, async: true

  alias Lux.Integrations.Telegram.GroupManager

  test "runs an offline group moderation workflow" do
    {:ok, system} = GroupManager.permission_system(%{chat_id: -100_123})

    {:ok, restrict} =
      GroupManager.member_action_plan(%{
        action: :restrict,
        chat_id: -100_123,
        user_id: 42,
        permissions: :read_only
      })

    {:ok, moderation} =
      GroupManager.moderation_action_plan(%{
        actor_id: "bot",
        message: %{
          chat_id: -100_123,
          message_id: 7,
          user_id: 42,
          text: "buy now http://spam.example @one @two @three @four @five @six"
        },
        rules: %{allow_links: false, mention_limit: 5, medium_action: :delete}
      })

    {:ok, audit} =
      GroupManager.audit_log([restrict.audit, moderation.audit], %{chat_id: -100_123})

    assert system.roles.read_only.chat_permissions.can_send_messages == false
    assert restrict.request.method == "restrictChatMember"
    assert moderation.action == :delete
    assert audit.count == 2
  end
end
