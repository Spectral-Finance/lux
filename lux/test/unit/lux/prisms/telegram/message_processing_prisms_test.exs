defmodule Lux.Prisms.Telegram.MessageProcessingPrismsTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Telegram.MessageProcessing.{
    AnalyzeContent,
    ParseCommand,
    RouteCommand,
    FormatMessage,
    ManageThread,
    ResolveReply,
    HandleDeepLink,
    ProcessCallbackQuery
  }

  alias Lux.Integrations.Telegram.MessageProcessing.CommandRouter

  describe "AnalyzeContent prism" do
    test "analyzes raw message payload" do
      msg = %{
        message_id: 1,
        text: "/start",
        from: %{id: 123, first_name: "John"},
        chat: %{id: 456, type: "private"}
      }

      assert {:ok, result} = AnalyzeContent.handler(%{message: msg}, %{})
      assert result.message_id == 1
      assert result.message_type == :text
      assert result.sender.first_name == "John"
    end
  end

  describe "ParseCommand prism" do
    test "extracts command and arguments" do
      params = %{text: "/deposit 500 USDT --fast", bot_username: "LuxBot"}
      assert {:ok, result} = ParseCommand.handler(params, %{})
      assert result.is_command == true
      assert result.command == "deposit"
      assert result.args == [500, "USDT"]
      assert result.options.fast == true
    end
  end

  describe "RouteCommand prism" do
    test "routes command via CommandRouter" do
      router =
        CommandRouter.new()
        |> CommandRouter.register("balance", fn _cmd, _ctx -> {:ok, %{balance: 1000}} end)

      {:ok, cmd} =
        Lux.Integrations.Telegram.MessageProcessing.CommandParser.parse("/balance")

      params = %{command: cmd, router: router, context: %{user_id: 123}}
      assert {:ok, %{status: "ok", result: {:ok, %{balance: 1000}}}} =
               RouteCommand.handler(params, %{})
    end
  end

  describe "FormatMessage prism" do
    test "formats markdown to telegram HTML and chunks" do
      params = %{
        text: "*Important update:* Check `docs` now!",
        format: "html",
        source_format: "markdown"
      }

      assert {:ok, result} = FormatMessage.handler(params, %{})
      assert result.parse_mode == "HTML"
      assert String.contains?(result.formatted_text, "<b>Important update:</b>")
      assert String.contains?(result.formatted_text, "<code>docs</code>")
      assert result.chunk_count == 1
    end
  end

  describe "ManageThread prism" do
    test "extracts forum topic thread info" do
      params = %{
        message: %{
          message_id: 88,
          message_thread_id: 15,
          chat: %{id: -100_999}
        }
      }

      assert {:ok, result} = ManageThread.handler(params, %{})
      assert result.is_thread == true
      assert result.thread_id == 15
      assert result.reply_params.message_thread_id == 15
    end
  end

  describe "ResolveReply prism" do
    test "extracts reply details and quotes" do
      params = %{
        message: %{
          message_id: 99,
          reply_to_message: %{
            message_id: 90,
            text: "Hello world"
          }
        },
        quote: "world"
      }

      assert {:ok, result} = ResolveReply.handler(params, %{})
      assert result.has_reply == true
      assert result.reply_params.quote == "world"
    end
  end

  describe "HandleDeepLink prism" do
    test "parses deep link payloads" do
      assert {:ok, result} =
               HandleDeepLink.handler(%{action: "parse", payload: "/start ref_user99"}, %{})

      assert result.status == "ok"
      assert result.data.type == :referral
      assert result.data.code == "user99"
    end

    test "generates deep link urls" do
      assert {:ok, result} =
               HandleDeepLink.handler(
                 %{
                   action: "generate",
                   bot_username: "LuxFinanceBot",
                   payload: "auth_token123",
                   link_type: "bot"
                 },
                 %{}
               )

      assert result.status == "ok"
      assert result.url == "https://t.me/LuxFinanceBot?start=auth_token123"
    end
  end

  describe "ProcessCallbackQuery prism" do
    test "processes callback queries and generates answer payload" do
      query = %{
        id: "cb_999",
        data: "confirm:tx_123",
        from: %{id: 42, first_name: "Alice"}
      }

      params = %{
        callback_query: query,
        answer_text: "Transaction confirmed",
        show_alert: true
      }

      assert {:ok, result} = ProcessCallbackQuery.handler(params, %{})
      assert result.id == "cb_999"
      assert result.action == "confirm"
      assert result.args == ["tx_123"]
      assert result.answer_params.text == "Transaction confirmed"
      assert result.answer_params.show_alert == true
    end
  end
end
