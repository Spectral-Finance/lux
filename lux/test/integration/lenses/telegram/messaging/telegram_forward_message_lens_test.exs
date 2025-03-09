defmodule Lux.Integration.Telegram.TelegramForwardMessageLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Telegram.ForwardMessage
  alias Lux.Lenses.Telegram.SendMessage

  # This test module assumes you have a valid Telegram bot token configured
  # and a chat ID where the bot can send messages

  # Use a test chat ID where your bot can send messages
  @test_chat_id System.get_env("TELEGRAM_TEST_CHAT_ID", "123456789")

  defmodule NoAuthTelegramForwardMessageLens do
    @moduledoc """
    Going to call the API without auth so that we always fail
    """
    use Lux.Lens,
      name: "Telegram Forward Message API",
      description: "Forwards messages via the Telegram Bot API",
      url: "https://api.telegram.org/bot/forwardMessage",
      method: :post,
      headers: [{"content-type", "application/json"}]
  end

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
      IO.puts("Skipping Telegram integration test - no token configured")
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
      IO.puts("Skipping Telegram integration test - no token configured")
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
      IO.puts("Skipping Telegram integration test - no token configured")
      :ok
    end
  end

  test "fails when no auth is provided" do
    assert {:error, _} =
             NoAuthTelegramForwardMessageLens.focus(%{
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
               ForwardMessage.focus(%{
                 chat_id: @test_chat_id,
                 from_chat_id: @test_chat_id,
                 message_id: invalid_message_id
               })

      # The error is a map with description, error_code, and ok fields
      assert is_map(error)
      assert Map.has_key?(error, "description")
      assert String.contains?(error["description"], "message to forward not found") or
             String.contains?(error["description"], "message not found") or
             String.contains?(error["description"], "message_id")
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
               ForwardMessage.focus(%{
                 chat_id: invalid_chat_id,
                 from_chat_id: @test_chat_id,
                 message_id: 1
               })

      # The error is a map with description, error_code, and ok fields
      assert is_map(error)
      assert Map.has_key?(error, "description")
      assert String.contains?(error["description"], "chat not found") or
             String.contains?(error["description"], "invalid") or
             String.contains?(error["description"], "chat_id")
    else
      IO.puts("Skipping Telegram integration test - no token configured")
      :ok
    end
  end
end
