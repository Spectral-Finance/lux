defmodule Lux.Integrations.Telegram.GroupManagement.ContentModeratorTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.GroupManagement.ContentModerator

  describe "ContentModerator" do
    test "detects banned scam words" do
      msg = %{
        text: "Special airdrop claim! Free crypto for everyone!",
        message_id: 123
      }

      assert {:ok, eval} = ContentModerator.check_content(msg)
      assert eval.violation == :banned_word
      assert eval.recommended_action == :delete_and_warn
      assert eval.severity == :high
    end

    test "detects unauthorized Telegram invite links" do
      msg = %{
        text: "Join our trading signal channel at https://t.me/fake_signals",
        message_id: 124
      }

      assert {:ok, eval} = ContentModerator.check_content(msg)
      assert eval.violation == :unauthorized_link
      assert eval.recommended_action == :delete_and_mute
      assert eval.severity == :medium
    end

    test "detects mass mentions" do
      msg = %{
        text: "Attention @user1 @user2 @user3 @user4 @user5 urgent!",
        message_id: 125,
        entities: []
      }

      assert {:ok, eval} = ContentModerator.check_content(msg)
      assert eval.violation == :mass_mention
      assert eval.mention_count >= 5
    end

    test "passes clean messages" do
      msg = %{
        text: "What do you think about the latest Ethereum rollup specs?",
        message_id: 126
      }

      assert {:ok, eval} = ContentModerator.check_content(msg)
      assert eval.violation == nil
      assert eval.recommended_action == :none
    end

    test "delete_message/3 deletes message via Client" do
      plug = fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["chat_id"] == -100_123
        assert decoded["message_id"] == 456

        Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      assert {:ok, _} = ContentModerator.delete_message(-100_123, 456, plug: plug)
    end
  end
end
