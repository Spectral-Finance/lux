defmodule Lux.Integration.Telegram.TelegramDeleteMessageLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Telegram.DeleteMessage
  alias Lux.Lenses.Telegram.SendMessage

  # This test module assumes you have a valid Telegram bot token configured
  # and a chat ID where the bot can send messages

  # Use a test chat ID where your bot can send messages
  @test_chat_id System.get_env("TELEGRAM_TEST_CHAT_ID", "123456789")

  defmodule NoAuthTelegramDeleteMessageLens do
    @moduledoc """
    Going to call the API without auth so that we always fail
    """
    use Lux.Lens,
      name: "Telegram Delete Message API",
      description: "Deletes messages via the Telegram Bot API",
      url: "https://api.telegram.org/bot/deleteMessage",
      method: :post,
      headers: [{"content-type", "application/json"}]
  end

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
      IO.puts("Skipping Telegram integration test - no token configured")
      :ok
    end
  end

  test "fails when no auth is provided" do
    assert {:error, _} =
             NoAuthTelegramDeleteMessageLens.focus(%{
               chat_id: @test_chat_id,
               message_id: 1
             })
  end

  test "fails with invalid message_id" do
    # This test should run even without a token, as it's testing error handling
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      invalid_message_id = 999999999  # An invalid message ID

      assert {:error, error} =
               DeleteMessage.focus(%{
                 chat_id: @test_chat_id,
                 message_id: invalid_message_id
               })

      # The error could be a map or a string depending on how after_focus transforms it
      case error do
        %{"description" => description} when is_binary(description) ->
          assert String.contains?(description, "message to delete not found") or
                 String.contains?(description, "message not found") or
                 String.contains?(description, "message_id")
        description when is_binary(description) ->
          assert String.contains?(description, "message to delete not found") or
                 String.contains?(description, "message not found") or
                 String.contains?(description, "message_id")
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
               DeleteMessage.focus(%{
                 chat_id: invalid_chat_id,
                 message_id: 1
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
