defmodule Lux.Integrations.Telegram.MessageProcessing.ReplyManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.MessageProcessing.ReplyManager

  describe "ReplyManager" do
    test "detects replies accurately" do
      msg_reply = %{message_id: 200, reply_to_message: %{message_id: 199, text: "original"}}
      msg_normal = %{message_id: 201, text: "standalone"}

      assert ReplyManager.reply?(msg_reply)
      refute ReplyManager.reply?(msg_normal)
    end

    test "resolves replied message details" do
      msg = %{
        message_id: 205,
        text: "I agree with this point",
        reply_to_message: %{
          message_id: 200,
          date: 1_700_000_000,
          from: %{id: 999, first_name: "Vitalik"},
          text: "Ethereum scalability plan"
        }
      }

      assert {:ok, result} = ReplyManager.resolve_reply(msg)
      assert result.has_reply == true
      assert result.replied_message_id == 200
      assert result.replied_sender.first_name == "Vitalik"
      assert result.replied_text == "Ethereum scalability plan"
      assert result.quote == nil
    end

    test "resolves modern Telegram Bot API 7.0+ quote object" do
      msg = %{
        message_id: 210,
        text: "Clarification on quote",
        reply_to_message: %{
          message_id: 200,
          text: "Full long message about layer 2 rollups and danksharding"
        },
        quote: %{
          text: "danksharding",
          position: 45,
          is_manual: true
        }
      }

      assert {:ok, result} = ReplyManager.resolve_reply(msg)
      assert result.quote.text == "danksharding"
      assert result.quote.position == 45
      assert result.quote.is_manual == true
    end

    test "build_reply_parameters/2 formats API 7.0+ reply_parameters" do
      msg = %{message_id: 777}

      params = ReplyManager.build_reply_parameters(msg)
      assert params.message_id == 777
      assert params.allow_sending_without_reply == true
      refute Map.has_key?(params, :quote)

      quoted_params =
        ReplyManager.build_reply_parameters(msg, quote: "specific line", quote_position: 10)

      assert quoted_params.quote == "specific line"
      assert quoted_params.quote_position == 10
    end

    test "format_llm_context/1 builds context with quote" do
      msg = %{
        text: "What does this mean?",
        reply_to_message: %{
          from: %{first_name: "Alice"},
          text: "Zero knowledge proofs provide privacy"
        }
      }

      context = ReplyManager.format_llm_context(msg)
      assert String.contains?(context, "[Replying to Alice]: Zero knowledge proofs provide privacy")
      assert String.contains?(context, "What does this mean?")
    end
  end
end
