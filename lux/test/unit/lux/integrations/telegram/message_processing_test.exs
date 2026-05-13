defmodule Lux.Integrations.Telegram.MessageProcessingTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.MessageProcessing
  alias Lux.Prisms.Telegram.Processing.AnalyzeUpdate
  alias Lux.Prisms.Telegram.Processing.FormatText
  alias Lux.Prisms.Telegram.Processing.ParseCommand

  test "parses commands with bot mentions and quoted args" do
    assert MessageProcessing.parse_command(~s(/trade@LuxBot buy "ETH spot" 1), "LuxBot") == %{
             command: "trade",
             bot: "LuxBot",
             raw_args: ~s(buy "ETH spot" 1),
             args: ["buy", "ETH spot", "1"],
             addressed?: true
           }

    assert %{addressed?: false} = MessageProcessing.parse_command("/trade@OtherBot buy", "LuxBot")
    assert MessageProcessing.parse_command("not a command", "LuxBot") == nil
  end

  test "escapes Telegram MarkdownV2 and HTML" do
    assert MessageProcessing.escape_markdown_v2("A_B (x)!") == "A\\_B \\(x\\)\\!"
    assert MessageProcessing.escape_html(~s(<b>&")) == "&lt;b&gt;&amp;&quot;"
  end

  test "analyzes message update with command, thread, reply, and deep link" do
    update = %{
      "update_id" => 10,
      "message" => %{
        "message_id" => 20,
        "message_thread_id" => 30,
        "text" => "/start onboard%20123",
        "chat" => %{"id" => -100},
        "from" => %{"id" => 42},
        "reply_to_message" => %{
          "message_id" => 19,
          "text" => "previous",
          "chat" => %{"id" => -100},
          "from" => %{"id" => 7}
        }
      }
    }

    analysis = MessageProcessing.analyze_update(update, bot_username: "LuxBot")

    assert analysis.type == :text
    assert analysis.chat_id == -100
    assert analysis.user_id == 42
    assert analysis.command.command == "start"
    assert analysis.deep_link == %{payload: "onboard%20123", decoded: "onboard 123"}
    assert analysis.thread == %{message_id: 20, thread_id: 30, chat_id: -100}
    assert analysis.reply == %{message_id: 19, chat_id: -100, user_id: 7, text: "previous"}
  end

  test "analyzes callback queries" do
    update = %{
      "callback_query" => %{
        "id" => "cb-1",
        "data" => "approve:123",
        "from" => %{"id" => 42},
        "message" => %{"message_id" => 20, "chat" => %{"id" => -100}}
      }
    }

    assert %{type: :callback_query, callback_query: callback} =
             MessageProcessing.analyze_update(update)

    assert callback == %{
             id: "cb-1",
             data: "approve:123",
             from_id: 42,
             message_id: 20,
             chat_id: -100
           }
  end

  test "processing prisms wrap helper functions" do
    assert {:ok, %{command: "ping", args: ["one"]}} =
             ParseCommand.handler(%{text: "/ping one"}, nil)

    assert {:ok, %{parse_mode: "HTML", text: "&lt;x&gt;"}} =
             FormatText.handler(%{text: "<x>", mode: "HTML"}, nil)

    assert {:ok, %{type: :text}} =
             AnalyzeUpdate.handler(%{update: %{"message" => %{"text" => "hi"}}}, nil)
  end
end
