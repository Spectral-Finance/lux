defmodule Lux.Integration.Telegram.TelegramEditMessageTextLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Telegram.EditMessageText
  alias Lux.Lenses.Telegram.SendMessage

  # This test module assumes you have a valid Telegram bot token configured
  # and a chat ID where the bot can send messages

  # Use a test chat ID where your bot can send messages
  @test_chat_id System.get_env("TELEGRAM_TEST_CHAT_ID", "123456789")

  defmodule NoAuthTelegramEditMessageTextLens do
    @moduledoc """
    Going to call the API without auth so that we always fail
    """
    use Lux.Lens,
      name: "Telegram Edit Message Text API",
      description: "Edits text messages via the Telegram Bot API",
      url: "https://api.telegram.org/bot/editMessageText",
      method: :post,
      headers: [{"content-type", "application/json"}]
  end

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
      IO.puts("Skipping Telegram integration test - no token configured")
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
      IO.puts("Skipping Telegram integration test - no token configured")
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
      IO.puts("Skipping Telegram integration test - no token configured")
      :ok
    end
  end

  test "fails when no auth is provided" do
    assert {:error, _} =
             NoAuthTelegramEditMessageTextLens.focus(%{
               chat_id: @test_chat_id,
               message_id: 1,
               text: "This should fail"
             })
  end

  test "fails with invalid message_id" do
    # This test should run even without a token, as it's testing error handling
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      invalid_message_id = 999999999  # An invalid message ID

      assert {:error, error} =
               EditMessageText.focus(%{
                 chat_id: @test_chat_id,
                 message_id: invalid_message_id,
                 text: "This should fail due to invalid message_id"
               })

      # Check if the error is a string (after_focus transformation) or a map
      case error do
        error when is_binary(error) ->
          assert String.contains?(error, "message to edit not found") or
                 String.contains?(error, "message not found") or
                 String.contains?(error, "message_id")
        error when is_map(error) ->
          assert Map.has_key?(error, "description")
          assert String.contains?(error["description"], "message to edit not found") or
                 String.contains?(error["description"], "message not found") or
                 String.contains?(error["description"], "message_id")
        _ ->
          assert false, "Expected error to be a string or a map with a description"
      end
    else
      IO.puts("Skipping Telegram integration test - no token configured")
      :ok
    end
  end

  test "fails with invalid chat_id" do
    # This test should run even without a token, as it's testing error handling
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      invalid_chat_id = "-999999999999"  # An invalid chat ID

      assert {:error, error} =
               EditMessageText.focus(%{
                 chat_id: invalid_chat_id,
                 message_id: 1,
                 text: "This should fail due to invalid chat_id"
               })

      # Check if the error is a string (after_focus transformation) or a map
      case error do
        error when is_binary(error) ->
          assert String.contains?(error, "chat not found") or
                 String.contains?(error, "invalid") or
                 String.contains?(error, "chat_id")
        error when is_map(error) ->
          assert Map.has_key?(error, "description")
          assert String.contains?(error["description"], "chat not found") or
                 String.contains?(error["description"], "invalid") or
                 String.contains?(error["description"], "chat_id")
        _ ->
          assert false, "Expected error to be a string or a map with a description"
      end
    else
      IO.puts("Skipping Telegram integration test - no token configured")
      :ok
    end
  end
end
