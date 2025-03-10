defmodule Lux.Integration.Telegram.TelegramDeleteMessageLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Telegram.DeleteMessage
  alias Lux.Lenses.Telegram.SendMessage

  # This test module assumes you have a valid Telegram bot token configured
  # and a chat ID where the bot can send messages

  # Use a test chat ID where your bot can send messages
  @test_chat_id System.get_env("TELEGRAM_TEST_CHAT_ID", "123456789")

  test "can delete a message" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      # First, send a message to get a message_id
      test_message = "Test message to be deleted from DeleteMessage at #{DateTime.utc_now()}"

      assert {:ok, original_message} =
               SendMessage.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message
               })

      # Now delete that message
      assert {:ok, true} =
               DeleteMessage.focus(%{
                 chat_id: @test_chat_id,
                 message_id: original_message.message_id
               })
    else
      :ok
    end
  end
end
