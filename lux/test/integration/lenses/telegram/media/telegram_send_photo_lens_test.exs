defmodule Lux.Integration.Telegram.TelegramSendPhotoLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Telegram.SendPhoto

  # This test module assumes you have a valid Telegram bot token configured
  # and a chat ID where the bot can send messages

  # Use a test chat ID where your bot can send messages
  @test_chat_id System.get_env("TELEGRAM_TEST_CHAT_ID", "123456789")
  @test_photo_url "https://via.placeholder.com/300"

  test "can send a photo with URL" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      test_caption = "Test photo sent from SendPhoto at #{DateTime.utc_now()}"

      assert {:ok, result} =
               SendPhoto.focus(%{
                 chat_id: @test_chat_id,
                 photo: @test_photo_url,
                 caption: test_caption
               })

      assert is_number(result.message_id)
      assert result.chat["id"] == String.to_integer(@test_chat_id)
      assert result.caption == test_caption
      assert is_list(result.photo)
      assert length(result.photo) > 0
      # Each photo size should have a file_id
      Enum.each(result.photo, fn photo ->
        assert Map.has_key?(photo, "file_id")
        assert Map.has_key?(photo, "file_unique_id")
        assert Map.has_key?(photo, "width")
        assert Map.has_key?(photo, "height")
      end)
    else
      :ok
    end
  end

  test "can send a photo with markdown formatting in caption" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      test_caption = "*Bold* and _italic_ caption from SendPhoto at #{DateTime.utc_now()}"

      assert {:ok, result} =
               SendPhoto.focus(%{
                 chat_id: @test_chat_id,
                 photo: @test_photo_url,
                 caption: test_caption,
                 parse_mode: "Markdown"
               })

      assert is_number(result.message_id)
      # Telegram may strip formatting in the response, so we don't check exact text match
      assert is_binary(result.caption)
      assert String.contains?(result.caption, "Bold") and String.contains?(result.caption, "italic")
      assert is_list(result.photo)
    else
      :ok
    end
  end

  test "can send a photo with silent notification" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      test_caption = "Silent photo from SendPhoto at #{DateTime.utc_now()}"

      assert {:ok, result} =
               SendPhoto.focus(%{
                 chat_id: @test_chat_id,
                 photo: @test_photo_url,
                 caption: test_caption,
                 disable_notification: true
               })

      assert is_number(result.message_id)
      assert result.caption == test_caption
      assert is_list(result.photo)
    else
      :ok
    end
  end

  test "can send a photo with protected content" do
    # Skip this test if we're not in integration mode or if the token is not set
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      test_caption = "Protected photo from SendPhoto at #{DateTime.utc_now()}"

      assert {:ok, result} =
               SendPhoto.focus(%{
                 chat_id: @test_chat_id,
                 photo: @test_photo_url,
                 caption: test_caption,
                 protect_content: true
               })

      assert is_number(result.message_id)
      assert result.caption == test_caption
      assert is_list(result.photo)
    else
      :ok
    end
  end
end
