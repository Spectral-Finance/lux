defmodule Lux.Integration.Telegram.Messaging.TelegramCopyMessageLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Telegram.Messaging.TelegramCopyMessageLens
  alias Lux.Lenses.Telegram.Messaging.TelegramSendMessageLens

  # This test module assumes you have a valid Telegram bot token configured
  # and a chat ID where the bot can send messages

  # Use a test chat ID where your bot can send messages
  @test_chat_id System.get_env("TELEGRAM_TEST_CHAT_ID", "123456789")

  defmodule NoAuthTelegramCopyMessageLens do
    @moduledoc """
    Going to call the API without auth so that we always fail
    """
    use Lux.Lens,
      name: "Telegram Copy Message API",
      description: "Copies messages via the Telegram Bot API",
      url: "https://api.telegram.org/bot/copyMessage",
      method: :post,
      headers: [{"content-type", "application/json"}]
  end

  test "can copy a message" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      # First, send a message to get a message_id
      test_message = "Test message to be copied from TelegramCopyMessageLens at #{DateTime.utc_now()}"

      assert {:ok, original_message} =
               TelegramSendMessageLens.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message
               })

      # Now copy that message
      assert {:ok, result} =
               TelegramCopyMessageLens.focus(%{
                 chat_id: @test_chat_id,
                 from_chat_id: @test_chat_id,
                 message_id: original_message.message_id
               })

      assert is_number(result.message_id)
    else
      IO.puts("Skipping Telegram integration test - no token configured")
      :ok
    end
  end

  test "can copy a message with disable_notification" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      # First, send a message to get a message_id
      test_message = "Silent copied message from TelegramCopyMessageLens at #{DateTime.utc_now()}"

      assert {:ok, original_message} =
               TelegramSendMessageLens.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message
               })

      # Now copy that message silently
      assert {:ok, result} =
               TelegramCopyMessageLens.focus(%{
                 chat_id: @test_chat_id,
                 from_chat_id: @test_chat_id,
                 message_id: original_message.message_id,
                 disable_notification: true
               })

      assert is_number(result.message_id)
    else
      IO.puts("Skipping Telegram integration test - no token configured")
      :ok
    end
  end

  test "can copy a message with protect_content" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      # First, send a message to get a message_id
      test_message = "Protected copied message from TelegramCopyMessageLens at #{DateTime.utc_now()}"

      assert {:ok, original_message} =
               TelegramSendMessageLens.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message
               })

      # Now copy that message with content protection
      assert {:ok, result} =
               TelegramCopyMessageLens.focus(%{
                 chat_id: @test_chat_id,
                 from_chat_id: @test_chat_id,
                 message_id: original_message.message_id,
                 protect_content: true
               })

      assert is_number(result.message_id)
    else
      IO.puts("Skipping Telegram integration test - no token configured")
      :ok
    end
  end

  test "can copy a message with a new caption" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      # First, send a message to get a message_id
      test_message = "Message to be copied with a new caption from TelegramCopyMessageLens at #{DateTime.utc_now()}"

      assert {:ok, original_message} =
               TelegramSendMessageLens.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message
               })

      # Now copy that message with a new caption
      new_caption = "New caption for copied message at #{DateTime.utc_now()}"

      assert {:ok, result} =
               TelegramCopyMessageLens.focus(%{
                 chat_id: @test_chat_id,
                 from_chat_id: @test_chat_id,
                 message_id: original_message.message_id,
                 caption: new_caption
               })

      assert is_number(result.message_id)
    else
      IO.puts("Skipping Telegram integration test - no token configured")
      :ok
    end
  end

  test "fails when no auth is provided" do
    assert {:error, _} =
             NoAuthTelegramCopyMessageLens.focus(%{
               chat_id: @test_chat_id,
               from_chat_id: @test_chat_id,
               message_id: 1
             })
  end

  test "fails with invalid message_id" do
    # This test should run even without a token, as it's testing error handling
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      invalid_message_id = 999999999  # An invalid message ID

      assert {:error, error} =
               TelegramCopyMessageLens.focus(%{
                 chat_id: @test_chat_id,
                 from_chat_id: @test_chat_id,
                 message_id: invalid_message_id
               })

      # Check if the error is a string (after_focus transformation) or a map
      case error do
        error when is_binary(error) ->
          assert String.contains?(error, "message to copy not found") or
                 String.contains?(error, "message not found") or
                 String.contains?(error, "message_id")
        error when is_map(error) ->
          assert Map.has_key?(error, "description")
          assert String.contains?(error["description"], "message to copy not found") or
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
               TelegramCopyMessageLens.focus(%{
                 chat_id: invalid_chat_id,
                 from_chat_id: @test_chat_id,
                 message_id: 1
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
