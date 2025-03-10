defmodule Lux.Integration.Telegram.TelegramCopyMessageLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Telegram.CopyMessage
  alias Lux.Lenses.Telegram.SendMessage

  # This test module assumes you have a valid Telegram bot token configured
  # and a chat ID where the bot can send messages

  # Use a test chat ID where your bot can send messages
  @test_chat_id System.get_env("TELEGRAM_TEST_CHAT_ID", "123456789")

  test "can copy a message" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      # First, send a message to get a message_id
      test_message = "Test message to be copied from CopyMessage at #{DateTime.utc_now()}"

      assert {:ok, original_message} =
               SendMessage.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message
               })

      # Now copy that message
      assert {:ok, result} =
               CopyMessage.focus(%{
                 chat_id: @test_chat_id,
                 from_chat_id: @test_chat_id,
                 message_id: original_message.message_id
               })

      assert is_number(result.message_id)
    else
      :ok
    end
  end

  test "can copy a message with disable_notification" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      # First, send a message to get a message_id
      test_message = "Silent copied message from CopyMessage at #{DateTime.utc_now()}"

      assert {:ok, original_message} =
               SendMessage.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message
               })

      # Now copy that message silently
      assert {:ok, result} =
               CopyMessage.focus(%{
                 chat_id: @test_chat_id,
                 from_chat_id: @test_chat_id,
                 message_id: original_message.message_id,
                 disable_notification: true
               })

      assert is_number(result.message_id)
    else
      :ok
    end
  end

  test "can copy a message with protect_content" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      # First, send a message to get a message_id
      test_message = "Protected copied message from CopyMessage at #{DateTime.utc_now()}"

      assert {:ok, original_message} =
               SendMessage.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message
               })

      # Now copy that message with content protection
      assert {:ok, result} =
               CopyMessage.focus(%{
                 chat_id: @test_chat_id,
                 from_chat_id: @test_chat_id,
                 message_id: original_message.message_id,
                 protect_content: true
               })

      assert is_number(result.message_id)
    else
      :ok
    end
  end

  test "can copy a message with a new caption" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      # First, send a message to get a message_id
      test_message = "Message to be copied with a new caption from CopyMessage at #{DateTime.utc_now()}"

      assert {:ok, original_message} =
               SendMessage.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message
               })

      # Now copy that message with a new caption
      new_caption = "New caption for copied message at #{DateTime.utc_now()}"

      assert {:ok, result} =
               CopyMessage.focus(%{
                 chat_id: @test_chat_id,
                 from_chat_id: @test_chat_id,
                 message_id: original_message.message_id,
                 caption: new_caption
               })

      assert is_number(result.message_id)
    else
      :ok
    end
  end
end
