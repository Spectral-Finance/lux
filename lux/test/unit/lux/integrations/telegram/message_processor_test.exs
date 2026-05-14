defmodule Lux.Integrations.Telegram.MessageProcessorTest do
  use UnitCase, async: true

  alias Lux.Integrations.Telegram.MessageProcessor

  test "processes commands with bot mentions and arguments" do
    update = %{
      "update_id" => 10,
      "message" => %{
        "message_id" => 7,
        "message_thread_id" => 42,
        "text" => "/trade@LuxBot symbol=ETH side=long",
        "chat" => %{"id" => -100, "type" => "supergroup", "title" => "Ops"},
        "from" => %{"id" => 1, "username" => "alice", "language_code" => "en"}
      }
    }

    assert {:ok, processed} = MessageProcessor.process_update(update, bot_username: "LuxBot")
    assert processed.update_type == :message
    assert processed.message_type == :text
    assert processed.command.command == "trade"
    assert %{key: "symbol", value: "ETH"} in processed.command.args
    assert processed.thread.thread_id == 42
    assert processed.chat.type == "supergroup"
    assert processed.route == %{action: :command, target: "trade"}
  end

  test "ignores commands addressed to another bot" do
    assert {:ok, processed} =
             MessageProcessor.process_update(
               %{"message" => %{"text" => "/trade@OtherBot symbol=ETH"}},
               bot_username: "LuxBot"
             )

    assert processed.command == nil
    assert processed.route == %{action: :message, target: :text}
  end

  test "extracts reply context and format-safe text" do
    update = %{
      message: %{
        message_id: 8,
        text: "Use *bold* <tag>",
        reply_to_message: %{
          message_id: 4,
          text: "Original",
          from: %{id: 2, username: "bob"}
        }
      }
    }

    assert {:ok, processed} = MessageProcessor.process_update(update)
    assert processed.reply.message_id == 4
    assert processed.formatting.markdown_v2 == "Use \\*bold\\* <tag\\>"
    assert processed.formatting.html == "Use *bold* &lt;tag&gt;"
    assert processed.route == %{action: :reply, target: :thread}
  end

  test "parses callback query context" do
    update = %{
      callback_query: %{
        id: "cb-1",
        data: "wallet:approve:42",
        from: %{id: 1},
        message: %{message_id: 9, chat: %{id: 10}}
      }
    }

    assert {:ok, processed} = MessageProcessor.process_update(update)
    assert processed.update_type == :callback_query
    assert processed.message_type == :callback_query
    assert processed.callback.parts == %{namespace: "wallet", action: "approve", id: "42"}
    assert processed.route == %{action: :handle_callback, target: :callback_query}
  end

  test "parses start deep links" do
    assert MessageProcessor.parse_deep_link("/start campaign_wallet_123") == %{
             payload: "campaign_wallet_123",
             parts: ["campaign", "wallet", "123"]
           }
  end

  test "lists supported message types" do
    assert :photo in MessageProcessor.message_types()
    assert :successful_payment in MessageProcessor.message_types()
  end

  test "rejects non-map updates" do
    assert {:error, "Expected a Telegram update map"} = MessageProcessor.process_update([])
  end
end
