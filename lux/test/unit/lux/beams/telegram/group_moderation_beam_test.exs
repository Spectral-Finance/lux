defmodule Lux.Beams.Telegram.GroupModerationBeamTest do
  use ExUnit.Case, async: true

  alias Lux.Beams.Telegram.GroupModerationBeam

  describe "GroupModerationBeam" do
    test "moderates message with violation and records audit log" do
      plug = fn conn ->
        Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      msg = %{
        chat_id: -100_999,
        message_id: 1234,
        text: "Claim your airdrop claim now!",
        from: %{id: 555, first_name: "Spammer"}
      }

      assert {:ok, result} =
               GroupModerationBeam.moderate_message(-100_999, msg,
                 execute_action: true,
                 plug: plug
               )

      assert result.moderation.violation == "banned_word"
      assert result.moderation.action == "delete_and_warn"
      assert result.moderation.executed == true
      assert result.audit_log.action == "delete_and_warn"
      assert result.audit_log.target_id == 555
      assert String.contains?(result.audit_log.formatted_html, "AUDIT LOG")
    end

    test "passes clean message through moderation pipeline" do
      msg = %{
        chat_id: -100_999,
        message_id: 1235,
        text: "Hello everyone, welcome to the community!",
        from: %{id: 777, first_name: "Alice"}
      }

      assert {:ok, result} = GroupModerationBeam.moderate_message(-100_999, msg)
      assert result.moderation.violation == nil
      assert result.moderation.action == "none"
      assert result.moderation.executed == false
      assert result.audit_log.action == "none"
    end
  end
end
