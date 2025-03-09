defmodule Lux.Integration.Telegram.TelegramEditMessageCaptionLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Telegram.EditMessageCaption
  alias Lux.Lenses.Telegram.SendPhoto

  # This test module assumes you have a valid Telegram bot token configured
  # and a chat ID where the bot can send messages

  # Use a test chat ID where your bot can send messages
  @test_chat_id System.get_env("TELEGRAM_TEST_CHAT_ID", "123456789")
  @test_photo_url "https://via.placeholder.com/300"

  defmodule NoAuthTelegramEditMessageCaptionLens do
    @moduledoc """
    Going to call the API without auth so that we always fail
    """
    use Lux.Lens,
      name: "Telegram Edit Message Caption API",
      description: "Edits message captions via the Telegram Bot API",
      url: "https://api.telegram.org/bot/editMessageCaption",
      method: :post,
      headers: [{"content-type", "application/json"}]
  end

  test "can edit a message caption" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      # First, send a photo with a caption to get a message_id
      test_caption = "Test caption to be edited from EditMessageCaption at #{DateTime.utc_now()}"

      assert {:ok, original_message} =
               SendPhoto.focus(%{
                 chat_id: @test_chat_id,
                 photo: @test_photo_url,
                 caption: test_caption
               })

      # Now edit that message's caption
      updated_caption = "Updated caption from EditMessageCaption at #{DateTime.utc_now()}"

      assert {:ok, result} =
               EditMessageCaption.focus(%{
                 chat_id: @test_chat_id,
                 message_id: original_message.message_id,
                 caption: updated_caption
               })

      assert is_number(result.message_id)
      assert result.message_id == original_message.message_id
      assert result.caption == updated_caption
      assert result.edit_date != nil
    else
      IO.puts("Skipping Telegram integration test - no token configured")
      :ok
    end
  end

  test "can edit a message with markdown formatting" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      # First, send a photo with a caption to get a message_id
      test_caption = "Test caption to be edited with formatting at #{DateTime.utc_now()}"

      assert {:ok, original_message} =
               SendPhoto.focus(%{
                 chat_id: @test_chat_id,
                 photo: @test_photo_url,
                 caption: test_caption
               })

      # Now edit that message with markdown formatting
      updated_caption = "*Bold* and _italic_ caption edited at #{DateTime.utc_now()}"

      assert {:ok, result} =
               EditMessageCaption.focus(%{
                 chat_id: @test_chat_id,
                 message_id: original_message.message_id,
                 caption: updated_caption,
                 parse_mode: "Markdown"
               })

      assert is_number(result.message_id)
      assert result.message_id == original_message.message_id
      # Telegram may strip formatting in the response, so we don't check exact text match
      assert is_binary(result.caption)
      assert String.contains?(result.caption, "Bold") and String.contains?(result.caption, "italic")
    else
      IO.puts("Skipping Telegram integration test - no token configured")
      :ok
    end
  end

  test "fails when no auth is provided" do
    assert {:error, _} =
             NoAuthTelegramEditMessageCaptionLens.focus(%{
               chat_id: @test_chat_id,
               message_id: 1,
               caption: "This should fail"
             })
  end

  test "fails with invalid message_id" do
    # This test should run even without a token, as it's testing error handling
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      invalid_message_id = 999999999  # An invalid message ID

      assert {:error, error} =
               EditMessageCaption.focus(%{
                 chat_id: @test_chat_id,
                 message_id: invalid_message_id,
                 caption: "This should fail due to invalid message_id"
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
               EditMessageCaption.focus(%{
                 chat_id: invalid_chat_id,
                 message_id: 1,
                 caption: "This should fail due to invalid chat_id"
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
