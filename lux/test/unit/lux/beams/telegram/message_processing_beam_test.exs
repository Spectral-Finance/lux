defmodule Lux.Beams.Telegram.MessageProcessingBeamTest do
  use ExUnit.Case, async: true

  alias Lux.Beams.Telegram.MessageProcessingBeam

  describe "MessageProcessingBeam" do
    test "processes incoming Telegram message through complete pipeline" do
      msg = %{
        message_id: 1001,
        date: 1_700_000_000,
        text: "/trade BTC 0.5 --slippage=1",
        from: %{
          id: 777_888,
          is_bot: false,
          first_name: "Trader",
          username: "crypto_trader"
        },
        chat: %{
          id: -100_777,
          type: "supergroup",
          title: "Trading Desk",
          is_forum: true
        },
        message_thread_id: 99,
        is_topic_message: true,
        reply_to_message: %{
          message_id: 999,
          text: "Should we buy BTC now?",
          from: %{id: 111, first_name: "Analyst"}
        }
      }

      assert {:ok, result} =
               MessageProcessingBeam.process_message(msg, bot_username: "LuxTraderBot")

      # Analysis verification
      assert result.analysis.message_type == :text
      assert result.analysis.sender.username == "crypto_trader"
      assert result.analysis.flags.is_reply == true
      assert result.analysis.flags.is_topic_message == true

      # Thread verification
      assert result.thread_context.is_thread == true
      assert result.thread_context.thread_id == 99
      assert result.thread_context.reply_params.message_thread_id == 99

      # Reply verification
      assert result.reply_context.has_reply == true
      assert result.reply_context.replied_message.replied_message_id == 999
      assert String.contains?(result.reply_context.llm_context, "Should we buy BTC now?")

      # Command verification
      assert result.command_context.is_command == true
      assert result.command_context.command == "trade"
      assert result.command_context.args == ["BTC", 0.5]
      assert result.command_context.options.slippage == 1
    end

    test "handles regular message without commands or thread" do
      msg = %{
        message_id: 1002,
        text: "Just checking in!",
        from: %{id: 123, first_name: "User"},
        chat: %{id: 123, type: "private"}
      }

      assert {:ok, result} = MessageProcessingBeam.process_message(msg)
      assert result.analysis.message_type == :text
      assert result.thread_context.is_thread == false
      assert result.reply_context.has_reply == false
      assert result.command_context.is_command == false
    end
  end
end
