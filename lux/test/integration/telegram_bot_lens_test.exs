defmodule Lux.Integration.TelegramBotLensTest do
  use IntegrationCase, async: true

  alias Lux.Lenses.TelegramBotLens

  # This test is tagged as :external because it requires a real Telegram Bot API token
  # and will make actual API calls to Telegram.
  @moduletag :external

  # For integration tests, you need to set up a test bot and add your chat ID here
  # You can get your chat ID by sending a message to @userinfobot on Telegram
  @test_chat_id System.get_env("TELEGRAM_TEST_CHAT_ID") || "1234567890"

  describe "TelegramBotLens integration - basic functionality" do
    @tag :integration
    test "can get bot information" do
      assert {:ok, bot_info} = TelegramBotLens.get_me()
      IO.puts("Bot info: #{inspect(bot_info, pretty: true)}")
      assert is_map(bot_info)
      assert bot_info["is_bot"] == true
      assert is_binary(bot_info["username"])
    end

    @tag :integration
    test "can send a message" do
      # Generate a unique message to avoid duplicate message detection
      test_message = "Test message from Lux integration test at #{DateTime.utc_now()}"

      assert {:ok, message} = TelegramBotLens.send_message(@test_chat_id, test_message)
      IO.puts("Message sent: #{inspect(message, pretty: true)}")
      assert is_map(message)
      assert is_integer(message["message_id"])
      assert message["text"] == test_message
    end

    @tag :integration
    test "can send a message with markdown formatting" do
      # Generate a unique message to avoid duplicate message detection
      test_message = "*Bold text* _Italic text_ `Code` [Link](https://example.com) #{DateTime.utc_now()}"

      assert {:ok, message} = TelegramBotLens.send_message(
        @test_chat_id,
        test_message,
        %{parse_mode: "Markdown"}
      )
      IO.puts("Markdown message sent: #{inspect(message, pretty: true)}")
      assert is_map(message)
      assert is_integer(message["message_id"])
      assert message["entities"] != nil
    end

    @tag :integration
    test "can send a message with HTML formatting" do
      # Generate a unique message to avoid duplicate message detection
      test_message = "<b>Bold text</b> <i>Italic text</i> <code>Code</code> <a href='https://example.com'>Link</a> #{DateTime.utc_now()}"

      assert {:ok, message} = TelegramBotLens.send_message(
        @test_chat_id,
        test_message,
        %{parse_mode: "HTML"}
      )
      IO.puts("HTML message sent: #{inspect(message, pretty: true)}")
      assert is_map(message)
      assert is_integer(message["message_id"])
      assert message["entities"] != nil
    end

    @tag :integration
    test "handles error for invalid chat ID" do
      assert {:error, error} = TelegramBotLens.send_message(
        "invalid_chat_id",
        "This should fail"
      )
      IO.puts("Error response: #{inspect(error, pretty: true)}")

      # Handle both map and atom/string error formats
      case error do
        error when is_map(error) ->
          assert error["description"] =~ "chat not found"

        :chat_not_found ->
          # This is the expected atom error from the ErrorHandler
          assert true

        error when is_binary(error) ->
          assert error =~ "chat not found"
      end
    end
  end

  describe "TelegramBotLens integration - media handling" do
    @tag :integration
    test "can send a photo by URL" do
      # Use a public image URL for testing
      photo_url = "https://upload.wikimedia.org/wikipedia/commons/thumb/0/0f/Grosser_Panda.JPG/330px-Grosser_Panda.JPG"
      caption = "Test photo from Lux integration test at #{DateTime.utc_now()}"

      assert {:ok, message} = TelegramBotLens.send_photo(
        @test_chat_id,
        photo_url,
        %{caption: caption}
      )
      IO.puts("Photo message sent: #{inspect(message, pretty: true)}")
      assert is_map(message)
      assert is_integer(message["message_id"])
      assert message["caption"] == caption
      assert is_list(message["photo"])
    end

    @tag :integration
    test "can send a document by URL" do
      # Use a public PDF URL for testing
      document_url = "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf"
      caption = "Test document from Lux integration test at #{DateTime.utc_now()}"

      assert {:ok, message} = TelegramBotLens.send_document(
        @test_chat_id,
        document_url,
        %{caption: caption}
      )
      IO.puts("Document message sent: #{inspect(message, pretty: true)}")
      assert is_map(message)
      assert is_integer(message["message_id"])
      assert message["caption"] == caption
      assert is_map(message["document"])
    end

    @tag :integration
    test "can send a video by URL" do
      # Use a public video URL for testing
      video_url = "https://filesamples.com/samples/video/mp4/sample_640x360.mp4"
      caption = "Test video from Lux integration test at #{DateTime.utc_now()}"

      assert {:ok, message} = TelegramBotLens.send_video(
        @test_chat_id,
        video_url,
        %{caption: caption}
      )
      IO.puts("Video message sent: #{inspect(message, pretty: true)}")
      assert is_map(message)
      assert is_integer(message["message_id"])
      assert message["caption"] == caption

      # Telegram might return the video as animation, document, or both
      assert (is_map(message["video"]) || is_map(message["animation"]) || is_map(message["document"]))
    end

    @tag :integration
    test "can send an audio file by URL" do
      # Use a public audio URL for testing
      audio_url = "https://filesamples.com/samples/audio/mp3/sample3.mp3"
      caption = "Test audio from Lux integration test at #{DateTime.utc_now()}"

      assert {:ok, message} = TelegramBotLens.send_audio(
        @test_chat_id,
        audio_url,
        %{caption: caption}
      )
      IO.puts("Audio message sent: #{inspect(message, pretty: true)}")
      assert is_map(message)
      assert is_integer(message["message_id"])
      assert message["caption"] == caption

      # Telegram might return the audio as voice, audio, or document
      assert (is_map(message["audio"]) || is_map(message["voice"]) || is_map(message["document"]))
    end

    @tag :integration
    test "can send a voice message" do
      # Use a public voice file URL for testing
      voice_url = "https://filesamples.com/samples/audio/ogg/sample3.ogg"
      caption = "Test voice message from Lux integration test at #{DateTime.utc_now()}"

      assert {:ok, message} = TelegramBotLens.send_voice(
        @test_chat_id,
        voice_url,
        %{caption: caption}
      )
      IO.puts("Voice message sent: #{inspect(message, pretty: true)}")
      assert is_map(message)
      assert is_integer(message["message_id"])
      assert message["caption"] == caption

      # Telegram might return the voice as voice, audio, or document
      assert (is_map(message["voice"]) || is_map(message["audio"]) || is_map(message["document"]))
    end
  end

  describe "TelegramBotLens integration - interactive elements" do
    @tag :integration
    test "can send a location" do
      # San Francisco coordinates
      latitude = 37.7749
      longitude = -122.4194

      assert {:ok, message} = TelegramBotLens.send_location(
        @test_chat_id,
        latitude,
        longitude
      )
      IO.puts("Location message sent: #{inspect(message, pretty: true)}")
      assert is_map(message)
      assert is_integer(message["message_id"])
      assert is_map(message["location"])

      # Use approximate comparison for coordinates since Telegram might adjust them slightly
      assert_in_delta message["location"]["latitude"], latitude, 0.001
      assert_in_delta message["location"]["longitude"], longitude, 0.001
    end

    @tag :integration
    test "can send a location with live period" do
      # New York coordinates
      latitude = 40.7128
      longitude = -74.0060

      assert {:ok, message} = TelegramBotLens.send_location(
        @test_chat_id,
        latitude,
        longitude,
        %{live_period: 60} # Live for 60 seconds
      )
      IO.puts("Live location message sent: #{inspect(message, pretty: true)}")
      assert is_map(message)
      assert is_integer(message["message_id"])
      assert is_map(message["location"])
      assert message["location"]["live_period"] != nil
    end
  end

  describe "TelegramBotLens integration - webhook management" do
    @tag :integration
    test "can get webhook info" do
      assert {:ok, webhook_info} = TelegramBotLens.get_webhook_info()
      IO.puts("Webhook info: #{inspect(webhook_info, pretty: true)}")
      assert is_map(webhook_info)
      # We don't assert specific values because the webhook might or might not be set
    end

    @tag :integration
    test "can get updates" do
      # We only test that the API call works, not that we actually get updates
      # since there might not be any pending updates
      assert {:ok, updates} = TelegramBotLens.get_updates(%{limit: 5})
      IO.puts("Updates: #{inspect(updates, pretty: true)}")
      assert is_list(updates)
    end

    # Note: We don't test setting and deleting webhooks in the integration tests
    # because that would affect the actual bot's webhook configuration.
    # These operations are covered by unit tests.
  end

  describe "TelegramBotLens integration - advanced messaging" do
    @tag :integration
    test "can send a message with reply markup (inline keyboard)" do
      test_message = "Test message with inline keyboard at #{DateTime.utc_now()}"

      # Create an inline keyboard with two buttons
      inline_keyboard = %{
        "inline_keyboard" => [
          [
            %{"text" => "Button 1", "callback_data" => "button1"},
            %{"text" => "Button 2", "callback_data" => "button2"}
          ],
          [
            %{"text" => "Visit Website", "url" => "https://example.com"}
          ]
        ]
      }

      assert {:ok, message} = TelegramBotLens.send_message(
        @test_chat_id,
        test_message,
        %{reply_markup: inline_keyboard}
      )
      IO.puts("Message with inline keyboard sent: #{inspect(message, pretty: true)}")
      assert is_map(message)
      assert is_integer(message["message_id"])
      assert message["text"] == test_message
      assert message["reply_markup"] != nil
    end

    @tag :integration
    test "can send a message with disable_web_page_preview option" do
      test_message = "Test message with link but no preview: https://example.com #{DateTime.utc_now()}"

      assert {:ok, message} = TelegramBotLens.send_message(
        @test_chat_id,
        test_message,
        %{disable_web_page_preview: true}
      )
      IO.puts("Message with disabled preview sent: #{inspect(message, pretty: true)}")
      assert is_map(message)
      assert is_integer(message["message_id"])
      assert message["text"] == test_message
    end

    @tag :integration
    test "can send a message with disable_notification option" do
      test_message = "Test silent message at #{DateTime.utc_now()}"

      assert {:ok, message} = TelegramBotLens.send_message(
        @test_chat_id,
        test_message,
        %{disable_notification: true}
      )
      IO.puts("Silent message sent: #{inspect(message, pretty: true)}")
      assert is_map(message)
      assert is_integer(message["message_id"])
      assert message["text"] == test_message
    end
  end

  describe "TelegramBotLens integration - new media features" do
    @tag :integration
    test "can send a media group" do
      # Use public image URLs for testing
      media = [
        %{type: "photo", media: "https://upload.wikimedia.org/wikipedia/commons/thumb/0/0f/Grosser_Panda.JPG/330px-Grosser_Panda.JPG", caption: "Panda"},
        %{type: "photo", media: "https://upload.wikimedia.org/wikipedia/commons/thumb/7/73/Lion_waiting_in_Namibia.jpg/330px-Lion_waiting_in_Namibia.jpg", caption: "Lion"}
      ]

      assert {:ok, messages} = TelegramBotLens.send_media_group(@test_chat_id, media)
      IO.puts("Media group sent: #{inspect(messages, pretty: true)}")
      assert is_list(messages)
      assert length(messages) == 2

      # Check first message
      first_message = Enum.at(messages, 0)
      assert is_map(first_message)
      assert is_integer(first_message["message_id"])
      assert is_list(first_message["photo"])

      # Check second message
      second_message = Enum.at(messages, 1)
      assert is_map(second_message)
      assert is_integer(second_message["message_id"])
      assert is_list(second_message["photo"])
    end

    @tag :integration
    test "can send an animation" do
      # Use a public GIF URL for testing
      animation_url = "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExcDd6Y2g2Ym50Y3Fhb2JxbXd2cWF0aHB0Y2Vxa2VpYzVtdWFqcXdmaiZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/3o7TKSha51AtNlLOLu/giphy.gif"
      caption = "Test animation from Lux integration test at #{DateTime.utc_now()}"

      assert {:ok, message} = TelegramBotLens.send_animation(
        @test_chat_id,
        animation_url,
        %{caption: caption}
      )
      IO.puts("Animation message sent: #{inspect(message, pretty: true)}")
      assert is_map(message)
      assert is_integer(message["message_id"])
      assert message["caption"] == caption

      # Telegram might return the animation as animation, document, or video
      assert (is_map(message["animation"]) || is_map(message["document"]) || is_map(message["video"]))
    end
  end

  describe "TelegramBotLens integration - interactive content" do
    @tag :integration
    test "can send a poll" do
      question = "What's your favorite programming language?"
      options = ["Elixir", "Python", "JavaScript", "Rust", "Go"]

      assert {:ok, message} = TelegramBotLens.send_poll(
        @test_chat_id,
        question,
        options,
        %{is_anonymous: true}
      )
      IO.puts("Poll message sent: #{inspect(message, pretty: true)}")
      assert is_map(message)
      assert is_integer(message["message_id"])
      assert is_map(message["poll"])
      assert message["poll"]["question"] == question
      assert length(message["poll"]["options"]) == length(options)
    end

    @tag :integration
    test "can send a contact" do
      phone_number = "+15551234567"
      first_name = "John"
      last_name = "Doe"

      assert {:ok, message} = TelegramBotLens.send_contact(
        @test_chat_id,
        phone_number,
        first_name,
        %{last_name: last_name}
      )
      IO.puts("Contact message sent: #{inspect(message, pretty: true)}")
      assert is_map(message)
      assert is_integer(message["message_id"])
      assert is_map(message["contact"])
      assert message["contact"]["phone_number"] == phone_number
      assert message["contact"]["first_name"] == first_name
      assert message["contact"]["last_name"] == last_name
    end

    @tag :integration
    test "can send a sticker" do
      # Use a valid sticker ID from a real sticker
      sticker_id = "CAACAgUAAxkBAAEyOo9nwmKWV2cbpTTvvYb-3i3_COPWowACUAQAAi_32VWCTBgLkVLp0zYE"

      result = TelegramBotLens.send_sticker(@test_chat_id, sticker_id)

      case result do
        {:ok, message} ->
          IO.puts("Sticker message sent: #{inspect(message)}")
          assert is_map(message)
          assert Map.has_key?(message, "message_id")
          assert is_integer(message["message_id"])
          assert Map.has_key?(message, "sticker") || Map.has_key?(message, "document")

        {:error, error} ->
          # If we get an error, it should be a specific type of error related to the sticker
          IO.puts("Expected sticker error: #{inspect(error)}")
          error_description = if is_map(error), do: error["description"], else: error
          assert is_binary(error_description)
          assert String.contains?(error_description, "wrong file identifier") ||
                 String.contains?(error_description, "wrong remote file") ||
                 String.contains?(error_description, "wrong type of")
      end

      # Test passes either way since we're testing the API call works correctly
      # even if the specific sticker ID is no longer valid
      assert true
    end

    @tag :integration
    test "can send a dice" do
      assert {:ok, message} = TelegramBotLens.send_dice(@test_chat_id)
      IO.puts("Dice message sent: #{inspect(message, pretty: true)}")
      assert is_map(message)
      assert is_integer(message["message_id"])
      assert is_map(message["dice"])
      assert message["dice"]["emoji"] == "🎲"
      assert is_integer(message["dice"]["value"])
      assert message["dice"]["value"] >= 1 and message["dice"]["value"] <= 6
    end

    @tag :integration
    test "can send a dice with custom emoji" do
      emoji = "🎯"

      assert {:ok, message} = TelegramBotLens.send_dice(
        @test_chat_id,
        %{emoji: emoji}
      )
      IO.puts("Custom dice message sent: #{inspect(message, pretty: true)}")
      assert is_map(message)
      assert is_integer(message["message_id"])
      assert is_map(message["dice"])
      assert message["dice"]["emoji"] == emoji
      assert is_integer(message["dice"]["value"])
    end

    @tag :integration
    test "can send a venue" do
      # Eiffel Tower coordinates and details
      latitude = 48.8584
      longitude = 2.2945
      title = "Eiffel Tower"
      address = "Champ de Mars, 5 Av. Anatole France, 75007 Paris, France"

      assert {:ok, message} = TelegramBotLens.send_venue(
        @test_chat_id,
        latitude,
        longitude,
        title,
        address
      )
      IO.puts("Venue message sent: #{inspect(message, pretty: true)}")
      assert is_map(message)
      assert is_integer(message["message_id"])
      assert is_map(message["venue"])
      assert message["venue"]["title"] == title
      assert message["venue"]["address"] == address

      # Use approximate comparison for coordinates since Telegram might adjust them slightly
      assert_in_delta message["venue"]["location"]["latitude"], latitude, 0.001
      assert_in_delta message["venue"]["location"]["longitude"], longitude, 0.001
    end
  end

  describe "TelegramBotLens integration - message management" do
    @tag :integration
    test "can edit a message" do
      # First send a message
      original_text = "Original message at #{DateTime.utc_now()}"
      {:ok, original_message} = TelegramBotLens.send_message(@test_chat_id, original_text)
      message_id = original_message["message_id"]

      # Then edit it
      edited_text = "Edited message at #{DateTime.utc_now()}"
      assert {:ok, edited_message} = TelegramBotLens.edit_message_text(
        @test_chat_id,
        message_id,
        edited_text
      )
      IO.puts("Edited message: #{inspect(edited_message, pretty: true)}")
      assert is_map(edited_message)
      assert edited_message["message_id"] == message_id
      assert edited_message["text"] == edited_text
      assert edited_message["edit_date"] != nil
    end

    @tag :integration
    @tag :reply_test
    test "can reply to a message" do
      # First send a message
      original_text = "Message to be replied to at #{DateTime.utc_now()}"
      {:ok, original_message} = TelegramBotLens.send_message(@test_chat_id, original_text)
      message_id = original_message["message_id"]

      # Then reply to it
      reply_text = "This is a reply at #{DateTime.utc_now()}"
      assert {:ok, reply_message} = TelegramBotLens.send_message(
        @test_chat_id,
        reply_text,
        %{reply_to_message_id: message_id}
      )
      IO.puts("Reply message: #{inspect(reply_message, pretty: true)}")
      assert is_map(reply_message)
      assert is_integer(reply_message["message_id"])
      assert reply_message["text"] == reply_text
      assert reply_message["reply_to_message"] != nil
      assert reply_message["reply_to_message"]["message_id"] == message_id
    end

    @tag :integration
    test "can edit a message caption" do
      # First send a photo with caption
      photo_url = "https://upload.wikimedia.org/wikipedia/commons/thumb/0/0f/Grosser_Panda.JPG/330px-Grosser_Panda.JPG"
      original_caption = "Original caption at #{DateTime.utc_now()}"

      {:ok, original_message} = TelegramBotLens.send_photo(
        @test_chat_id,
        photo_url,
        %{caption: original_caption}
      )
      message_id = original_message["message_id"]

      # Then edit the caption
      edited_caption = "Edited caption at #{DateTime.utc_now()}"
      assert {:ok, edited_message} = TelegramBotLens.edit_message_caption(
        @test_chat_id,
        message_id,
        edited_caption
      )
      IO.puts("Edited caption message: #{inspect(edited_message, pretty: true)}")
      assert is_map(edited_message)
      assert edited_message["message_id"] == message_id
      assert edited_message["caption"] == edited_caption
    end

    @tag :integration
    test "can forward a message" do
      # First send a message
      original_text = "Message to be forwarded at #{DateTime.utc_now()}"
      {:ok, original_message} = TelegramBotLens.send_message(@test_chat_id, original_text)
      message_id = original_message["message_id"]

      # Then forward it to the same chat (for testing purposes)
      assert {:ok, forwarded_message} = TelegramBotLens.forward_message(
        @test_chat_id,
        @test_chat_id,
        message_id
      )
      IO.puts("Forwarded message: #{inspect(forwarded_message, pretty: true)}")
      assert is_map(forwarded_message)
      assert is_integer(forwarded_message["message_id"])
      assert forwarded_message["text"] == original_text
      assert forwarded_message["forward_date"] != nil
    end

    @tag :integration
    test "can copy a message" do
      # First send a message
      original_text = "Message to be copied at #{DateTime.utc_now()}"
      {:ok, original_message} = TelegramBotLens.send_message(@test_chat_id, original_text)
      message_id = original_message["message_id"]

      # Then copy it to the same chat (for testing purposes)
      assert {:ok, copied_message} = TelegramBotLens.copy_message(
        @test_chat_id,
        @test_chat_id,
        message_id
      )
      IO.puts("Copied message: #{inspect(copied_message, pretty: true)}")
      assert is_map(copied_message)
      assert is_integer(copied_message["message_id"])
    end

    @tag :integration
    test "can delete a message" do
      # First send a message
      text = "Message to be deleted at #{DateTime.utc_now()}"
      {:ok, message} = TelegramBotLens.send_message(@test_chat_id, text)
      message_id = message["message_id"]

      # Then delete it
      assert {:ok, result} = TelegramBotLens.delete_message(@test_chat_id, message_id)
      IO.puts("Delete message result: #{inspect(result, pretty: true)}")
      assert result == true
    end
  end

  describe "TelegramBotLens integration - chat management" do
    @tag :integration
    test "can get chat information" do
      assert {:ok, chat_info} = TelegramBotLens.get_chat(@test_chat_id)
      IO.puts("Chat info: #{inspect(chat_info, pretty: true)}")
      assert is_map(chat_info)
      assert to_string(chat_info["id"]) == @test_chat_id
      assert is_binary(chat_info["type"])
    end

    @tag :integration
    test "can get chat member count for a group" do
      # Skip this test if we're using a private chat
      # This test requires a group chat ID to work properly
      {:ok, chat_info} = TelegramBotLens.get_chat(@test_chat_id)

      if chat_info["type"] == "private" do
        IO.puts("Skipping chat member count test for private chat")
      else
        assert {:ok, count} = TelegramBotLens.get_chat_member_count(@test_chat_id)
        IO.puts("Chat member count: #{inspect(count, pretty: true)}")
        assert is_integer(count)
        assert count > 0
      end
    end

    @tag :integration
    test "can get chat member information" do
      # First get the bot's user ID
      {:ok, bot_info} = TelegramBotLens.get_me()
      bot_id = bot_info["id"]

      assert {:ok, member_info} = TelegramBotLens.get_chat_member(@test_chat_id, bot_id)
      IO.puts("Chat member info: #{inspect(member_info, pretty: true)}")
      assert is_map(member_info)
      assert is_map(member_info["user"])
      assert member_info["user"]["id"] == bot_id
    end
  end

  describe "TelegramBotLens integration - receiving messages" do
    @tag :integration
    @tag :manual_interaction
    test "can receive a reply to a message" do
      # First send a message asking for a reply
      prompt_text = "Please reply to this message with 'TEST REPLY' - Integration Test at #{DateTime.utc_now()}"
      {:ok, sent_message} = TelegramBotLens.send_message(@test_chat_id, prompt_text)
      message_id = sent_message["message_id"]

      IO.puts("\n\n========================================")
      IO.puts("MANUAL TEST INTERACTION REQUIRED")
      IO.puts("Please reply to the bot's message with 'TEST REPLY'")
      IO.puts("You have 60 seconds to respond")
      IO.puts("========================================\n\n")

      # Wait for a reply that contains "TEST REPLY"
      filter_fn = fn update ->
        update.type == :message and
        update.text != nil and
        String.contains?(String.upcase(update.text), "TEST REPLY")
      end

      case TelegramBotLens.wait_for_update(filter_fn, 60000) do
        {:ok, update} ->
          IO.puts("Received reply: #{inspect(update, pretty: true)}")
          assert update.type == :message
          assert String.contains?(String.upcase(update.text), "TEST REPLY")

          # If the message is a reply to our original message, verify that
          if update.raw["reply_to_message"] != nil do
            assert update.raw["reply_to_message"]["message_id"] == message_id
          end

        {:error, :timeout} ->
          flunk("Timed out waiting for reply")
      end
    end

    @tag :integration
    @tag :manual_interaction
    test "can process different types of updates" do
      # Send a message with instructions
      instructions = """
      Please perform ONE of the following actions within 60 seconds:
      1. Edit a message
      2. Send a sticker
      3. Vote in a poll

      Integration Test at #{DateTime.utc_now()}
      """

      {:ok, _} = TelegramBotLens.send_message(@test_chat_id, instructions)

      # Send a poll as an option for interaction
      question = "Test Poll - Please vote"
      options = ["Option 1", "Option 2", "Option 3"]
      {:ok, _} = TelegramBotLens.send_poll(@test_chat_id, question, options)

      IO.puts("\n\n========================================")
      IO.puts("MANUAL TEST INTERACTION REQUIRED")
      IO.puts("Please perform one of the actions listed in the message")
      IO.puts("You have 60 seconds to respond")
      IO.puts("========================================\n\n")

      # Wait for any update
      filter_fn = fn update ->
        # Accept any type of update
        true
      end

      case TelegramBotLens.wait_for_update(filter_fn, 60000) do
        {:ok, update} ->
          IO.puts("Received update: #{inspect(update, pretty: true)}")

          # Verify we got a valid update type
          assert update.type in [:message, :edited_message, :callback_query, :poll_answer]

          # Additional assertions based on the update type
          case update.type do
            :message ->
              assert is_integer(update.message_id)
              assert is_map(update.chat)

            :edited_message ->
              assert is_integer(update.message_id)
              assert is_map(update.chat)
              assert is_integer(update.edit_date)

            :callback_query ->
              assert is_binary(update.id)
              assert is_map(update.from)

            :poll_answer ->
              assert is_binary(update.poll_id)
              assert is_map(update.user)
              assert is_list(update.option_ids)
          end

        {:error, :timeout} ->
          flunk("Timed out waiting for interaction")
      end
    end

    @tag :integration
    test "can process updates from getUpdates" do
      # This test doesn't require manual interaction, it just tests
      # that we can process updates from the getUpdates API

      # Get some updates
      {:ok, updates} = TelegramBotLens.get_updates(%{limit: 5})

      # Process them
      processed_updates = TelegramBotLens.process_updates(updates)

      # We don't assert anything specific about the updates since there might not be any
      # Just verify that the processing function works
      assert is_list(processed_updates)

      # If there are updates, verify they were processed correctly
      if length(processed_updates) > 0 do
        Enum.each(processed_updates, fn update ->
          assert is_map(update)
          assert Map.has_key?(update, :type)
          assert Map.has_key?(update, :update_id)
        end)
      end
    end

    @tag :integration
    test "can get and process updates in one step" do
      # Test the convenience function
      {:ok, processed_updates} = TelegramBotLens.get_and_process_updates(%{limit: 5})

      # Verify the result structure
      assert is_list(processed_updates)

      # If there are updates, verify they were processed correctly
      if length(processed_updates) > 0 do
        Enum.each(processed_updates, fn update ->
          assert is_map(update)
          assert Map.has_key?(update, :type)
          assert Map.has_key?(update, :update_id)
        end)
      end
    end
  end
end
