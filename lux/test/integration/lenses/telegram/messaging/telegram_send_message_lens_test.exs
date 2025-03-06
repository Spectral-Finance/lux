defmodule Lux.Integration.Telegram.Messaging.TelegramSendMessageLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Telegram.Messaging.TelegramSendMessageLens

  # This test module assumes you have a valid Telegram bot token configured
  # and a chat ID where the bot can send messages

  # Use a test chat ID where your bot can send messages
  # This could be your own chat with the bot or a test group
  @test_chat_id System.get_env("TELEGRAM_TEST_CHAT_ID", "123456789")

  defmodule NoAuthTelegramSendMessageLens do
    @moduledoc """
    Going to call the API without auth so that we always fail
    """
    use Lux.Lens,
      name: "Telegram Send Message API",
      description: "Sends text messages via the Telegram Bot API",
      url: "https://api.telegram.org/bot/sendMessage",
      method: :post,
      headers: [{"content-type", "application/json"}]
  end

  test "can send a simple text message" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      test_message = "Test message from TelegramSendMessageLens at #{DateTime.utc_now()}"

      assert {:ok, result} =
               TelegramSendMessageLens.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message
               })

      assert is_number(result.message_id)
      assert result.chat["id"] == String.to_integer(@test_chat_id)
      assert result.text == test_message
    else
      IO.puts("Skipping Telegram integration test - no token configured")
      :ok
    end
  end

  test "can send a message with markdown formatting" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      test_message = "*Bold* and _italic_ message from TelegramSendMessageLens at #{DateTime.utc_now()}"

      assert {:ok, result} =
               TelegramSendMessageLens.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message,
                 parse_mode: "Markdown"
               })

      assert is_number(result.message_id)
      # Telegram may strip formatting in the response, so we don't check exact text match
      assert is_binary(result.text)
      assert String.contains?(result.text, "Bold") and String.contains?(result.text, "italic")
    else
      IO.puts("Skipping Telegram integration test - no token configured")
      :ok
    end
  end

  test "can send a message with HTML formatting" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      test_message = "<b>Bold</b> and <i>italic</i> message from TelegramSendMessageLens at #{DateTime.utc_now()}"

      assert {:ok, result} =
               TelegramSendMessageLens.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message,
                 parse_mode: "HTML"
               })

      assert is_number(result.message_id)
      # Telegram may strip formatting in the response, so we don't check exact text match
      assert is_binary(result.text)
      assert String.contains?(result.text, "Bold") and String.contains?(result.text, "italic")
    else
      IO.puts("Skipping Telegram integration test - no token configured")
      :ok
    end
  end

  test "can send a message with disabled notification" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      test_message = "Silent message from TelegramSendMessageLens at #{DateTime.utc_now()}"

      assert {:ok, result} =
               TelegramSendMessageLens.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message,
                 disable_notification: true
               })

      assert is_number(result.message_id)
      assert result.text == test_message
    else
      IO.puts("Skipping Telegram integration test - no token configured")
      :ok
    end
  end

  test "can send a message with disabled web page preview" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      test_message = "Message with link https://example.com from TelegramSendMessageLens at #{DateTime.utc_now()}"

      assert {:ok, result} =
               TelegramSendMessageLens.focus(%{
                 chat_id: @test_chat_id,
                 text: test_message,
                 disable_web_page_preview: true
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
             NoAuthTelegramSendMessageLens.focus(%{
               chat_id: @test_chat_id,
               text: "This should fail"
             })
  end

  test "fails with invalid chat_id" do
    # This test should run even without a token, as it's testing error handling
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      invalid_chat_id = "-999999999999"  # An invalid chat ID

      assert {:error, error} =
               TelegramSendMessageLens.focus(%{
                 chat_id: invalid_chat_id,
                 text: "This should fail due to invalid chat_id"
               })

      # The error could be a map or a string depending on how after_focus transforms it
      case error do
        %{"description" => description} when is_binary(description) ->
          assert String.contains?(description, "chat not found") or
                 String.contains?(description, "invalid") or
                 String.contains?(description, "chat_id")
        description when is_binary(description) ->
          assert String.contains?(description, "chat not found") or
                 String.contains?(description, "invalid") or
                 String.contains?(description, "chat_id")
        _ ->
          assert false, "Expected error to be a string or a map with a description"
      end
    else
      IO.puts("Skipping Telegram integration test - no token configured")
      :ok
    end
  end
end
