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
      :ok
    end
  end
end
