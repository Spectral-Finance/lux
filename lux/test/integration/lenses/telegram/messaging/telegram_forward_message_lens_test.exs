defmodule Lux.Integration.Telegram.TelegramForwardMessageLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Telegram.ForwardMessage
  alias Lux.Lenses.Telegram.SendMessage

  # This test module assumes you have a valid Telegram bot token configured
  # and a chat ID where the bot can send messages

  # Use a test chat ID where your bot can send messages
  @test_chat_id System.get_env("TELEGRAM_TEST_CHAT_ID", "123456789")

  test "can forward a message" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      # First, send a message to get a message_id
      test_message = "Test message to be forwarded from ForwardMessage at #{DateTime.utc_now()}"

      assert {:ok, original_message} =
               SendMessage.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message
               })

      # Now forward that message
      assert {:ok, result} =
               ForwardMessage.focus(%{
                 chat_id: @test_chat_id,
                 from_chat_id: @test_chat_id,
                 message_id: original_message.message_id
               })

      assert is_number(result.message_id)
      assert result.chat["id"] == String.to_integer(@test_chat_id)
      # The forward_from_chat field might be nil if the chat has privacy settings enabled
      # So we'll just check that the text matches
      assert result.text == test_message
    else
      :ok
    end
  end

  test "can forward a message with disable_notification" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      # First, send a message to get a message_id
      test_message = "Silent forwarded message from ForwardMessage at #{DateTime.utc_now()}"

      assert {:ok, original_message} =
               SendMessage.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message
               })

      # Now forward that message silently
      assert {:ok, result} =
               ForwardMessage.focus(%{
                 chat_id: @test_chat_id,
                 from_chat_id: @test_chat_id,
                 message_id: original_message.message_id,
                 disable_notification: true
               })

      assert is_number(result.message_id)
      assert result.text == test_message
    else
      :ok
    end
  end

  test "can forward a message with protect_content" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      # First, send a message to get a message_id
      test_message = "Protected forwarded message from ForwardMessage at #{DateTime.utc_now()}"

      assert {:ok, original_message} =
               SendMessage.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message
               })

      # Now forward that message with content protection
      assert {:ok, result} =
               ForwardMessage.focus(%{
                 chat_id: @test_chat_id,
                 from_chat_id: @test_chat_id,
                 message_id: original_message.message_id,
                 protect_content: true
               })

      assert is_number(result.message_id)
      assert result.text == test_message
    else
      :ok
    end
  end
end
