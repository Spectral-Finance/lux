defmodule Lux.Integration.Telegram.TelegramEditMessageTextLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Telegram.EditMessageText
  alias Lux.Lenses.Telegram.SendMessage

  # This test module assumes you have a valid Telegram bot token configured
  # and a chat ID where the bot can send messages

  # Use a test chat ID where your bot can send messages
  @test_chat_id System.get_env("TELEGRAM_TEST_CHAT_ID", "123456789")

  test "can edit a message text" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      # First, send a message to get a message_id
      test_message = "Test message to be edited from EditMessageText at #{DateTime.utc_now()}"

      assert {:ok, original_message} =
               SendMessage.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message
               })

      # Now edit that message
      updated_text = "Updated message text from EditMessageText at #{DateTime.utc_now()}"

      assert {:ok, result} =
               EditMessageText.focus(%{
                 chat_id: @test_chat_id,
                 message_id: original_message.message_id,
                 text: updated_text
               })

      assert is_number(result.message_id)
      assert result.message_id == original_message.message_id
      assert result.text == updated_text
      assert result.edit_date != nil
    else
      :ok
    end
  end

  test "can edit a message with markdown formatting" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      # First, send a message to get a message_id
      test_message = "Test message to be edited with formatting at #{DateTime.utc_now()}"

      assert {:ok, original_message} =
               SendMessage.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message
               })

      # Now edit that message with markdown formatting
      updated_text = "*Bold* and _italic_ text edited at #{DateTime.utc_now()}"

      assert {:ok, result} =
               EditMessageText.focus(%{
                 chat_id: @test_chat_id,
                 message_id: original_message.message_id,
                 text: updated_text,
                 parse_mode: "Markdown"
               })

      assert is_number(result.message_id)
      assert result.message_id == original_message.message_id
      # Telegram may strip formatting in the response, so we don't check exact text match
      assert is_binary(result.text)
      assert String.contains?(result.text, "Bold") and String.contains?(result.text, "italic")
    else
      :ok
    end
  end

  test "can edit a message with disabled web page preview" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      # First, send a message to get a message_id
      test_message = "Test message with link https://example.com at #{DateTime.utc_now()}"

      assert {:ok, original_message} =
               SendMessage.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message
               })

      # Now edit that message with disabled web page preview
      updated_text = "Updated message with link https://example.com at #{DateTime.utc_now()}"

      assert {:ok, result} =
               EditMessageText.focus(%{
                 chat_id: @test_chat_id,
                 message_id: original_message.message_id,
                 text: updated_text,
                 disable_web_page_preview: true
               })

      assert is_number(result.message_id)
      assert result.message_id == original_message.message_id
      assert result.text == updated_text
    else
      :ok
    end
  end
end
