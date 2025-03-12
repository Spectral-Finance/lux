defmodule Lux.Integration.Telegram.TelegramSendMessageLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Telegram.SendMessage

  # This test module assumes you have a valid Telegram bot token configured
  # and a chat ID where the bot can send messages

  # Use a test chat ID where your bot can send messages
  # This could be your own chat with the bot or a test group
  @test_chat_id System.get_env("TELEGRAM_TEST_CHAT_ID", "123456789")

  test "can send a simple text message" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      test_message = "Test message from SendMessage at #{DateTime.utc_now()}"

      assert {:ok, result} =
               SendMessage.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message
               })

      assert is_number(result.message_id)
      assert result.chat["id"] == String.to_integer(@test_chat_id)
      assert result.text == test_message
    else
      :ok
    end
  end

  test "can send a message with markdown formatting" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      test_message = "*Bold* and _italic_ message from SendMessage at #{DateTime.utc_now()}"

      assert {:ok, result} =
               SendMessage.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message,
                 parse_mode: "Markdown"
               })

      assert is_number(result.message_id)
      # Telegram may strip formatting in the response, so we don't check exact text match
      assert is_binary(result.text)
      assert String.contains?(result.text, "Bold") and String.contains?(result.text, "italic")
    else
      :ok
    end
  end

  test "can send a message with HTML formatting" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      test_message = "<b>Bold</b> and <i>italic</i> message from SendMessage at #{DateTime.utc_now()}"

      assert {:ok, result} =
               SendMessage.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message,
                 parse_mode: "HTML"
               })

      assert is_number(result.message_id)
      # Telegram may strip formatting in the response, so we don't check exact text match
      assert is_binary(result.text)
      assert String.contains?(result.text, "Bold") and String.contains?(result.text, "italic")
    else
      :ok
    end
  end

  test "can send a message with disabled notification" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      test_message = "Silent message from SendMessage at #{DateTime.utc_now()}"

      assert {:ok, result} =
               SendMessage.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message,
                 disable_notification: true
               })

      assert is_number(result.message_id)
      assert result.text == test_message
    else
      :ok
    end
  end

  test "can send a message with disabled web page preview" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      test_message = "Message with link https://example.com from SendMessage at #{DateTime.utc_now()}"

      assert {:ok, result} =
               SendMessage.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message,
                 disable_web_page_preview: true
               })

      assert is_number(result.message_id)
      assert result.text == test_message
    else
      :ok
    end
  end
end
