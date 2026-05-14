defmodule Lux.Prisms.Telegram.Group.ManageGroupTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Group.ManageGroup

  test "builds member plans through the prism" do
    assert {:ok, %{status: "success", result: plan}} =
             ManageGroup.run(%{
               action: "member_action",
               params: %{
                 action: :ban,
                 chat_id: -100_123,
                 user_id: 42,
                 reason: "spam"
               }
             })

    assert plan.request.method == "banChatMember"
    assert plan.request.payload.revoke_messages
  end

  test "moderates content through the prism" do
    assert {:ok, %{status: "success", result: result}} =
             ManageGroup.run(%{
               action: "moderate_content",
               params: %{
                 message: %{
                   chat_id: -100_123,
                   message_id: 11,
                   user_id: 42,
                   text: "visit http://spam.example"
                 },
                 rules: %{allow_links: false, medium_action: :delete}
               }
             })

    assert result.status == :delete
    assert Enum.any?(result.requests, &(&1.method == "deleteMessage"))
  end

  test "summarizes audit logs through the prism" do
    entries = [
      %{
        id: "a1",
        action: :ban,
        actor_id: "admin",
        chat_id: -100_123,
        target_user_id: 42,
        created_at: "2026-05-14T02:20:00Z"
      }
    ]

    assert {:ok, %{status: "success", result: audit}} =
             ManageGroup.run(%{
               action: "audit_log",
               params: %{entries: entries, filters: %{chat_id: -100_123}}
             })

    assert audit.count == 1
    assert audit.actions.ban == 1
  end
end
