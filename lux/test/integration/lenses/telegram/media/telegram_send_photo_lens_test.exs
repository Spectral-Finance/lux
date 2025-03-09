defmodule Lux.Integration.Telegram.TelegramSendPhotoLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Telegram.SendPhoto

  # This test module assumes you have a valid Telegram bot token configured
  # and a chat ID where the bot can send messages

  # Use a test chat ID where your bot can send messages
  @test_chat_id System.get_env("TELEGRAM_TEST_CHAT_ID", "123456789")
  @test_photo_url "https://via.placeholder.com/300"

  defmodule NoAuthTelegramSendPhotoLens do
    @moduledoc """
    Going to call the API without auth so that we always fail
    """
    use Lux.Lens,
      name: "Telegram Send Photo API",
      description: "Sends photos via the Telegram Bot API",
      url: "https://api.telegram.org/bot/sendPhoto",
      method: :post,
      headers: [{"content-type", "application/json"}]
  end

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
      IO.puts("Skipping Telegram integration test - no token configured")
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
      IO.puts("Skipping Telegram integration test - no token configured")
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
      IO.puts("Skipping Telegram integration test - no token configured")
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
      IO.puts("Skipping Telegram integration test - no token configured")
      :ok
    end
  end

  test "fails when no auth is provided" do
    assert {:error, _} =
             NoAuthTelegramSendPhotoLens.focus(%{
               chat_id: @test_chat_id,
               photo: @test_photo_url,
               caption: "This should fail"
             })
  end

  test "fails with invalid chat_id" do
    # This test should run even without a token, as it's testing error handling
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      invalid_chat_id = "-999999999999"  # An invalid chat ID

      assert {:error, error} =
               SendPhoto.focus(%{
                 chat_id: invalid_chat_id,
                 photo: @test_photo_url,
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

  test "fails with invalid photo URL" do
    # This test should run even without a token, as it's testing error handling
    if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
      invalid_photo_url = "https://invalid.example.com/nonexistent.jpg"

      assert {:error, error} =
               SendPhoto.focus(%{
                 chat_id: @test_chat_id,
                 photo: invalid_photo_url,
                 caption: "This should fail due to invalid photo URL"
               })

      # Check if the error is a string (after_focus transformation) or a map
      case error do
        error when is_binary(error) ->
          assert String.contains?(error, "failed") or
                 String.contains?(error, "wrong") or
                 String.contains?(error, "invalid") or
                 String.contains?(error, "Bad Request")
        error when is_map(error) ->
          assert Map.has_key?(error, "description")
          assert String.contains?(error["description"], "failed") or
                 String.contains?(error["description"], "wrong") or
                 String.contains?(error["description"], "invalid") or
                 String.contains?(error["description"], "Bad Request")
        _ ->
          assert false, "Expected error to be a string or a map with a description"
      end
    else
      IO.puts("Skipping Telegram integration test - no token configured")
      :ok
    end
  end
end
