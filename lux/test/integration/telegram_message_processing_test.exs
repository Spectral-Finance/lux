defmodule TelegramMessageProcessingTest do
  use ExUnit.Case, async: true

  @moduletag :integration

  alias Lux.Integrations.Telegram.MessageProcessor

  test "demonstrates command, reply, and callback processing" do
    command = %{
      message: %{
        message_id: 1,
        message_thread_id: 77,
        text: "/portfolio@LuxBot chain=base wallet=main",
        chat: %{id: -100, type: "supergroup"}
      }
    }

    reply = %{
      message: %{
        message_id: 2,
        text: "Looks good",
        reply_to_message: %{message_id: 1, text: "/portfolio chain=base"}
      }
    }

    callback = %{
      callback_query: %{
        id: "cb",
        data: "portfolio:refresh:main",
        message: %{message_id: 3}
      }
    }

    assert {:ok, %{route: %{action: :command}, command: %{command: "portfolio"}}} =
             MessageProcessor.process_update(command, bot_username: "LuxBot")

    assert {:ok, %{route: %{action: :reply}, reply: %{message_id: 1}}} =
             MessageProcessor.process_update(reply)

    assert {:ok, %{route: %{action: :handle_callback}, callback: %{parts: %{id: "main"}}}} =
             MessageProcessor.process_update(callback)
  end
end
