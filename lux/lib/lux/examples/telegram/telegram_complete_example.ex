defmodule Lux.Examples.TelegramCompleteExample do
  @moduledoc """
  A comprehensive example demonstrating all features of the TelegramBotLens module.

  This example includes:
  - Basic messaging and formatting
  - Media handling (photos, documents, videos, etc.)
  - Interactive elements (keyboards, polls, etc.)
  - Message management (editing, deleting, etc.)
  - Chat management
  - Webhook handling
  """

  alias Lux.Lenses.TelegramBotLens

  @doc """
  Runs all examples sequentially, demonstrating each feature of the TelegramBotLens.

  ## Parameters

  - `chat_id`: The chat ID to send messages to
  - `token`: Your Telegram Bot API token
  - `opts`: Additional options
    - `:webhook_url`: URL for webhook examples (optional)
    - `:skip_webhook`: Skip webhook examples (default: true)
    - `:delay`: Delay between examples in ms (default: 1000)

  ## Example

  ```elixir
  # Run all examples
  Lux.Examples.TelegramCompleteExample.run("YOUR_CHAT_ID", "YOUR_BOT_TOKEN")

  # Run with webhook examples
  Lux.Examples.TelegramCompleteExample.run("YOUR_CHAT_ID", "YOUR_BOT_TOKEN",
    webhook_url: "https://your-domain.com/webhook",
    skip_webhook: false
  )
  ```
  """
  def run(chat_id, token, opts \\ []) do
    webhook_url = Keyword.get(opts, :webhook_url)
    skip_webhook = Keyword.get(opts, :skip_webhook, true)
    delay = Keyword.get(opts, :delay, 1000)

    IO.puts("\n🚀 Starting Telegram Complete Example...")
    IO.puts("This example will demonstrate all features of the TelegramBotLens")

    # Store the token in the application environment
    Application.put_env(:lux, :api_keys, telegram_bot: token)

    # Basic Bot Information
    demonstrate_bot_info()
    Process.sleep(delay)

    # Basic Messaging
    demonstrate_basic_messaging(chat_id)
    Process.sleep(delay)

    # Message Formatting
    demonstrate_message_formatting(chat_id)
    Process.sleep(delay)

    # Media Handling
    demonstrate_media_handling(chat_id)
    Process.sleep(delay)

    # Interactive Elements
    demonstrate_interactive_elements(chat_id)
    Process.sleep(delay)

    # Inline Query Features
    demonstrate_inline_features()
    Process.sleep(delay)

    # Enhanced Polls and Quizzes
    demonstrate_polls_and_quizzes(chat_id)
    Process.sleep(delay)

    # Game Features
    demonstrate_game_features(chat_id)
    Process.sleep(delay)

    # Live Location Features
    demonstrate_live_location(chat_id)
    Process.sleep(delay)

    # Sticker Features
    demonstrate_sticker_features(chat_id)
    Process.sleep(delay)

    # Message Management
    demonstrate_message_management(chat_id)
    Process.sleep(delay)

    # Chat Management
    demonstrate_chat_management(chat_id)
    Process.sleep(delay)

    # Webhook Management (if enabled)
    unless skip_webhook do
      if webhook_url do
        demonstrate_webhook_management(webhook_url)
        Process.sleep(delay)
      else
        IO.puts("\n⚠️ Skipping webhook examples - no webhook URL provided")
      end
    end

    IO.puts("\n✅ All examples completed successfully!")
  end

  # Demonstrate getting bot information
  defp demonstrate_bot_info do
    IO.puts("\n📊 Demonstrating Bot Information...")

    case TelegramBotLens.get_me() do
      {:ok, bot_info} ->
        IO.puts("✅ Bot Information retrieved:")
        IO.puts("  Username: @#{bot_info["username"]}")
        IO.puts("  Bot ID: #{bot_info["id"]}")
        IO.puts("  Can join groups: #{bot_info["can_join_groups"]}")
        IO.puts("  Can read group messages: #{bot_info["can_read_all_group_messages"]}")
        IO.puts("  Supports inline queries: #{bot_info["supports_inline_queries"]}")

      {:error, error} ->
        IO.puts("❌ Failed to get bot information: #{inspect(error)}")
    end
  end

  # Demonstrate basic messaging features
  defp demonstrate_basic_messaging(chat_id) do
    IO.puts("\n💬 Demonstrating Basic Messaging...")

    # Simple text message
    case TelegramBotLens.send_message(chat_id, "Hello! This is a basic text message.") do
      {:ok, message} ->
        IO.puts("✅ Basic message sent (ID: #{message["message_id"]})")
      {:error, error} ->
        IO.puts("❌ Failed to send basic message: #{inspect(error)}")
    end

    # Message with notification disabled
    case TelegramBotLens.send_message(chat_id, "This is a silent message.", %{
      disable_notification: true
    }) do
      {:ok, message} ->
        IO.puts("✅ Silent message sent (ID: #{message["message_id"]})")
      {:error, error} ->
        IO.puts("❌ Failed to send silent message: #{inspect(error)}")
    end

    # Message with web preview disabled
    case TelegramBotLens.send_message(chat_id,
      "Message with link but no preview: https://example.com",
      %{disable_web_page_preview: true}
    ) do
      {:ok, message} ->
        IO.puts("✅ Message with disabled preview sent (ID: #{message["message_id"]})")
      {:error, error} ->
        IO.puts("❌ Failed to send message with disabled preview: #{inspect(error)}")
    end
  end

  # Demonstrate message formatting
  defp demonstrate_message_formatting(chat_id) do
    IO.puts("\n🎨 Demonstrating Message Formatting...")

    # Markdown formatting
    markdown_text = """
    *Bold text*
    _Italic text_
    `Inline code`
    ```
    Code block
    ```
    [Link](https://example.com)
    """

    case TelegramBotLens.send_message(chat_id, markdown_text, %{parse_mode: "Markdown"}) do
      {:ok, message} ->
        IO.puts("✅ Markdown message sent (ID: #{message["message_id"]})")
      {:error, error} ->
        IO.puts("❌ Failed to send markdown message: #{inspect(error)}")
    end

    # HTML formatting
    html_text = """
    <b>Bold text</b>
    <i>Italic text</i>
    <code>Inline code</code>
    <pre>Code block</pre>
    <a href="https://example.com">Link</a>
    """

    case TelegramBotLens.send_message(chat_id, html_text, %{parse_mode: "HTML"}) do
      {:ok, message} ->
        IO.puts("✅ HTML message sent (ID: #{message["message_id"]})")
      {:error, error} ->
        IO.puts("❌ Failed to send HTML message: #{inspect(error)}")
    end
  end

  # Demonstrate media handling
  defp demonstrate_media_handling(chat_id) do
    IO.puts("\n📸 Demonstrating Media Handling...")

    # Send photo
    photo_url = "https://upload.wikimedia.org/wikipedia/commons/thumb/0/0f/Grosser_Panda.JPG/330px-Grosser_Panda.JPG"
    case TelegramBotLens.send_photo(chat_id, photo_url, %{caption: "A cute panda!"}) do
      {:ok, message} ->
        IO.puts("✅ Photo sent (ID: #{message["message_id"]})")
      {:error, error} ->
        IO.puts("❌ Failed to send photo: #{inspect(error)}")
    end

    # Send document
    document_url = "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf"
    case TelegramBotLens.send_document(chat_id, document_url, %{caption: "A sample PDF"}) do
      {:ok, message} ->
        IO.puts("✅ Document sent (ID: #{message["message_id"]})")
      {:error, error} ->
        IO.puts("❌ Failed to send document: #{inspect(error)}")
    end

    # Send video
    video_url = "https://filesamples.com/samples/video/mp4/sample_640x360.mp4"
    case TelegramBotLens.send_video(chat_id, video_url, %{caption: "A sample video"}) do
      {:ok, message} ->
        IO.puts("✅ Video sent (ID: #{message["message_id"]})")
      {:error, error} ->
        IO.puts("❌ Failed to send video: #{inspect(error)}")
    end

    # Send animation (GIF)
    animation_url = "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExcDd6Y2g2Ym50Y3Fhb2JxbXd2cWF0aHB0Y2Vxa2VpYzVtdWFqcXdmaiZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/3o7TKSha51AtNlLOLu/giphy.gif"
    case TelegramBotLens.send_animation(chat_id, animation_url, %{caption: "A fun animation!"}) do
      {:ok, message} ->
        IO.puts("✅ Animation sent (ID: #{message["message_id"]})")
      {:error, error} ->
        IO.puts("❌ Failed to send animation: #{inspect(error)}")
    end

    # Send media group
    media = [
      %{type: "photo", media: photo_url, caption: "Photo 1"},
      %{type: "photo", media: "https://upload.wikimedia.org/wikipedia/commons/thumb/7/73/Lion_waiting_in_Namibia.jpg/330px-Lion_waiting_in_Namibia.jpg", caption: "Photo 2"}
    ]
    case TelegramBotLens.send_media_group(chat_id, media) do
      {:ok, messages} ->
        IO.puts("✅ Media group sent (#{length(messages)} items)")
      {:error, error} ->
        IO.puts("❌ Failed to send media group: #{inspect(error)}")
    end
  end

  # Demonstrate interactive elements
  defp demonstrate_interactive_elements(chat_id) do
    IO.puts("\n🎮 Demonstrating Interactive Elements...")

    # Send message with inline keyboard
    inline_keyboard = %{
      "inline_keyboard" => [
        [
          %{"text" => "Button 1", "callback_data" => "btn1"},
          %{"text" => "Button 2", "callback_data" => "btn2"}
        ],
        [
          %{"text" => "Visit Website", "url" => "https://example.com"}
        ]
      ]
    }

    case TelegramBotLens.send_message(chat_id, "Message with inline keyboard:", %{
      reply_markup: inline_keyboard
    }) do
      {:ok, message} ->
        IO.puts("✅ Message with inline keyboard sent (ID: #{message["message_id"]})")
      {:error, error} ->
        IO.puts("❌ Failed to send message with inline keyboard: #{inspect(error)}")
    end

    # Send poll
    case TelegramBotLens.send_poll(chat_id,
      "What's your favorite programming language?",
      ["Elixir", "Python", "JavaScript", "Rust", "Go"],
      %{is_anonymous: true}
    ) do
      {:ok, message} ->
        IO.puts("✅ Poll sent (ID: #{message["message_id"]})")
      {:error, error} ->
        IO.puts("❌ Failed to send poll: #{inspect(error)}")
    end

    # Send location
    case TelegramBotLens.send_location(chat_id, 37.7749, -122.4194) do
      {:ok, message} ->
        IO.puts("✅ Location sent (ID: #{message["message_id"]})")
      {:error, error} ->
        IO.puts("❌ Failed to send location: #{inspect(error)}")
    end

    # Send dice
    case TelegramBotLens.send_dice(chat_id) do
      {:ok, message} ->
        IO.puts("✅ Dice sent (ID: #{message["message_id"]})")
      {:error, error} ->
        IO.puts("❌ Failed to send dice: #{inspect(error)}")
    end

    # Send contact
    case TelegramBotLens.send_contact(chat_id, "+15551234567", "John", %{
      last_name: "Doe"
    }) do
      {:ok, message} ->
        IO.puts("✅ Contact sent (ID: #{message["message_id"]})")
      {:error, error} ->
        IO.puts("❌ Failed to send contact: #{inspect(error)}")
    end

    # Send venue
    case TelegramBotLens.send_venue(chat_id, 48.8584, 2.2945,
      "Eiffel Tower",
      "Champ de Mars, 5 Av. Anatole France, 75007 Paris, France"
    ) do
      {:ok, message} ->
        IO.puts("✅ Venue sent (ID: #{message["message_id"]})")
      {:error, error} ->
        IO.puts("❌ Failed to send venue: #{inspect(error)}")
    end
  end

  # Demonstrate inline query features
  defp demonstrate_inline_features do
    IO.puts("\n🔍 Demonstrating Inline Query Features...")
    IO.puts("Note: To test inline queries:")
    IO.puts("1. Make sure inline mode is enabled via @BotFather (/setinline)")
    IO.puts("2. Type @your_bot_name in any chat followed by a search term")
    IO.puts("3. The bot will respond with inline results")

    # Set up an example inline query handler
    TelegramBotLens.set_inline_handler(fn query ->
      search_term = query["query"]
      IO.puts("\nReceived inline query: #{search_term}")

      # Create different types of results based on the search term
      cond do
        String.contains?(search_term, "photo") ->
          # Photo result
          [
            TelegramBotLens.create_photo_result(
              "1",
              "https://upload.wikimedia.org/wikipedia/commons/thumb/0/0f/Grosser_Panda.JPG/330px-Grosser_Panda.JPG",
              "https://upload.wikimedia.org/wikipedia/commons/thumb/0/0f/Grosser_Panda.JPG/330px-Grosser_Panda.JPG",
              %{
                title: "Sample Photo",
                description: "A cute panda photo",
                caption: "You searched for a photo!"
              }
            )
          ]

        String.contains?(search_term, "article") ->
          # Article result
          [
            TelegramBotLens.create_article_result(
              "1",
              "Sample Article",
              TelegramBotLens.create_text_content(
                "*Article Result*\nYou searched for: #{search_term}",
                %{parse_mode: "Markdown"}
              ),
              %{
                description: "Click to send this article result",
                thumbnail_url: "https://upload.wikimedia.org/wikipedia/commons/thumb/0/0f/Grosser_Panda.JPG/330px-Grosser_Panda.JPG"
              }
            )
          ]

        true ->
          # Default text result
          [
            TelegramBotLens.create_article_result(
              "1",
              "Search Result",
              TelegramBotLens.create_text_content(
                "You searched for: #{search_term}"
              ),
              %{description: "Click to send the search result"}
            ),
            TelegramBotLens.create_article_result(
              "2",
              "Formatted Result",
              TelegramBotLens.create_text_content(
                "*Bold text*\n_Your search:_ #{search_term}",
                %{parse_mode: "Markdown"}
              ),
              %{description: "Click to send a formatted result"}
            )
          ]
      end
    end, %{
      cache_time: 300,  # Cache results for 5 minutes
      is_personal: true  # Results are personalized for each user
    })

    IO.puts("\n✅ Inline query handler set up successfully")
    IO.puts("Try typing @your_bot_name followed by:")
    IO.puts("- Any text for default results")
    IO.puts("- 'photo' for a photo result")
    IO.puts("- 'article' for an article result")
  end

  # Demonstrate enhanced polls and quizzes
  defp demonstrate_polls_and_quizzes(chat_id) do
    IO.puts("\n📊 Demonstrating Enhanced Polls and Quizzes...")

    # Regular poll with multiple answers
    case TelegramBotLens.send_poll(chat_id,
      "What programming languages do you use? (select all that apply)",
      ["Elixir", "Python", "JavaScript", "Rust", "Go"],
      %{
        is_anonymous: false,
        allows_multiple_answers: true,
        explanation: "Choose all languages you regularly use"
      }
    ) do
      {:ok, message} ->
        poll_message_id = message["message_id"]
        IO.puts("✅ Multiple-answer poll sent (ID: #{poll_message_id})")

        # Stop the poll after a delay
        Process.sleep(5000)
        case TelegramBotLens.stop_poll(chat_id, poll_message_id) do
          {:ok, _} ->
            IO.puts("✅ Poll stopped successfully")
          {:error, error} ->
            IO.puts("❌ Failed to stop poll: #{inspect(error)}")
        end

      {:error, error} ->
        IO.puts("❌ Failed to send multiple-answer poll: #{inspect(error)}")
    end

    # Quiz poll
    case TelegramBotLens.send_quiz(chat_id,
      "What is the primary programming language used in the Lux project?",
      ["Python", "JavaScript", "Elixir", "Rust"],
      2,  # Elixir is the correct answer (0-based index)
      %{
        explanation: "Lux is primarily written in Elixir",
        explanation_parse_mode: "Markdown",
        is_anonymous: false
      }
    ) do
      {:ok, message} ->
        IO.puts("✅ Quiz sent (ID: #{message["message_id"]})")
      {:error, error} ->
        IO.puts("❌ Failed to send quiz: #{inspect(error)}")
    end
  end

  # Demonstrate game features
  defp demonstrate_game_features(chat_id) do
    IO.puts("\n🎮 Demonstrating Game Features...")
    IO.puts("Note: To use game features, you need to:")
    IO.puts("1. Create a game with @BotFather using /newgame command")
    IO.puts("2. Set up your game's short name (in this case 'TEST') and URL")
    IO.puts("3. Make sure the game is properly configured in @BotFather")

    # First send the game
    case TelegramBotLens.send_game(chat_id, "TEST") do
      {:ok, message} ->
        message_id = message["message_id"]
        IO.puts("✅ Game message sent (ID: #{message_id})")

        # Get bot information to use its ID
        case TelegramBotLens.get_me() do
          {:ok, bot_info} ->
            bot_id = bot_info["id"]

            # Set a game score
            case TelegramBotLens.set_game_score(bot_id, 100, %{
              chat_id: chat_id,
              message_id: message_id,
              force: true  # Force update even if score is lower
            }) do
              {:ok, _} ->
                IO.puts("✅ Game score set successfully")

                # Get high scores
                case TelegramBotLens.get_game_high_scores(bot_id, %{
                  chat_id: chat_id,
                  message_id: message_id
                }) do
                  {:ok, scores} ->
                    IO.puts("✅ High scores retrieved:")
                    if length(scores) > 0 do
                      Enum.each(scores, fn score ->
                        IO.puts("  #{score["user"]["first_name"]}: #{score["score"]} points")
                      end)
                    else
                      IO.puts("  No high scores yet")
                    end
                  {:error, error} ->
                    IO.puts("❌ Failed to get high scores: #{inspect(error)}")
                end

              {:error, error} ->
                IO.puts("❌ Failed to set game score: #{inspect(error)}")
                if is_binary(error) and String.contains?(error, "GAME_SHORT_NAME_INVALID") do
                  IO.puts("\nℹ️ This error means the game 'TEST' is not properly configured.")
                  IO.puts("Please make sure to:")
                  IO.puts("1. Talk to @BotFather")
                  IO.puts("2. Use /newgame to create a game named 'TEST'")
                  IO.puts("3. Set up the game URL when prompted")
                end
            end

          {:error, error} ->
            IO.puts("❌ Failed to get bot information: #{inspect(error)}")
        end

      {:error, error} ->
        IO.puts("❌ Failed to send game: #{inspect(error)}")
        if is_binary(error) and String.contains?(error, "GAME_SHORT_NAME_INVALID") do
          IO.puts("\nℹ️ This error means the game 'TEST' is not properly configured.")
          IO.puts("Please make sure to:")
          IO.puts("1. Talk to @BotFather")
          IO.puts("2. Use /newgame to create a game named 'TEST'")
          IO.puts("3. Set up the game URL when prompted")
        end
    end
  end

  # Demonstrate live location features
  defp demonstrate_live_location(chat_id) do
    IO.puts("\n📍 Demonstrating Live Location Features...")

    # Send a live location
    case TelegramBotLens.send_live_location(chat_id,
      37.7749,  # San Francisco latitude
      -122.4194,  # San Francisco longitude
      60,  # Update for 60 seconds
      %{
        heading: 90,  # Heading in degrees
        proximity_alert_radius: 100  # Alert radius in meters
      }
    ) do
      {:ok, message} ->
        message_id = message["message_id"]
        IO.puts("✅ Live location sent (ID: #{message_id})")

        # Update the location after a delay
        Process.sleep(5000)
        case TelegramBotLens.edit_live_location(chat_id, message_id,
          37.7750,  # Slightly different latitude
          -122.4195,  # Slightly different longitude
          %{heading: 180}  # New heading
        ) do
          {:ok, _} ->
            IO.puts("✅ Live location updated")

            # Stop the live location
            Process.sleep(2000)
            case TelegramBotLens.stop_live_location(chat_id, message_id) do
              {:ok, _} ->
                IO.puts("✅ Live location stopped")
              {:error, error} ->
                IO.puts("❌ Failed to stop live location: #{inspect(error)}")
            end

          {:error, error} ->
            IO.puts("❌ Failed to update live location: #{inspect(error)}")
        end

      {:error, error} ->
        IO.puts("❌ Failed to send live location: #{inspect(error)}")
    end
  end

  # Demonstrate sticker features
  defp demonstrate_sticker_features(chat_id) do
    IO.puts("\n🎨 Demonstrating Sticker Features...")

    # Send a sticker using a known sticker ID
    sticker_id = "CAACAgUAAxkBAAEyOo9nwmKWV2cbpTTvvYb-3i3_COPWowACUAQAAi_32VWCTBgLkVLp0zYE"
    case TelegramBotLens.send_sticker(chat_id, sticker_id) do
      {:ok, message} ->
        IO.puts("✅ Sticker sent by ID (ID: #{message["message_id"]})")
      {:error, error} ->
        IO.puts("❌ Failed to send sticker by ID: #{inspect(error)}")
        # Try with an alternative sticker if the first one fails
        alternative_sticker_id = "CAACAgIAAxkBAAEKqPJlWU_AAWm-AAHlOzBF7AABYzJ-AAHXpgACGxsAAVGRAAHoC8HlhLEwBA"
        IO.puts("Trying with an alternative sticker...")
        case TelegramBotLens.send_sticker(chat_id, alternative_sticker_id) do
          {:ok, message} ->
            IO.puts("✅ Alternative sticker sent (ID: #{message["message_id"]})")
          {:error, error} ->
            IO.puts("❌ Failed to send alternative sticker: #{inspect(error)}")
        end
    end

    # Get information about a sticker set
    sticker_set_name = "EmojiOne"  # This is a common sticker set
    case TelegramBotLens.get_sticker_set(sticker_set_name) do
      {:ok, set_info} ->
        IO.puts("\n✅ Sticker set information retrieved:")
        IO.puts("  Name: #{set_info["name"]}")
        IO.puts("  Title: #{set_info["title"]}")
        IO.puts("  Contains #{length(set_info["stickers"])} stickers")

        # Send a sticker from the set
        if length(set_info["stickers"]) > 0 do
          sticker = Enum.at(set_info["stickers"], 0)
          case TelegramBotLens.send_sticker(chat_id, sticker["file_id"]) do
            {:ok, message} ->
              IO.puts("✅ Sticker from set sent (ID: #{message["message_id"]})")
            {:error, error} ->
              IO.puts("❌ Failed to send sticker from set: #{inspect(error)}")
          end
        end

      {:error, error} ->
        IO.puts("❌ Failed to get sticker set: #{inspect(error)}")
        IO.puts("Note: This is expected if the sticker set name is invalid or not accessible")
    end

    # Note: Creating new sticker sets requires the bot to be the owner
    # and requires uploading actual sticker files. This is just a demonstration
    # of the API structure.
    IO.puts("\nℹ️ Note: Creating new sticker sets requires the bot to be")
    IO.puts("   the owner and requires uploading actual sticker files.")
    IO.puts("   You can get sticker IDs by forwarding stickers to @idstickerbot")
  end

  # Demonstrate message management
  defp demonstrate_message_management(chat_id) do
    IO.puts("\n📝 Demonstrating Message Management...")

    # Send a message to edit
    case TelegramBotLens.send_message(chat_id, "Original message") do
      {:ok, message} ->
        message_id = message["message_id"]
        IO.puts("✅ Original message sent (ID: #{message_id})")

        # Edit the message
        case TelegramBotLens.edit_message_text(chat_id, message_id, "Edited message") do
          {:ok, edited_message} ->
            IO.puts("✅ Message edited (ID: #{edited_message["message_id"]})")
          {:error, error} ->
            IO.puts("❌ Failed to edit message: #{inspect(error)}")
        end

        # Send a message to forward
        case TelegramBotLens.send_message(chat_id, "Message to be forwarded") do
          {:ok, forward_message} ->
            forward_id = forward_message["message_id"]

            # Forward the message
            case TelegramBotLens.forward_message(chat_id, chat_id, forward_id) do
              {:ok, forwarded_message} ->
                IO.puts("✅ Message forwarded (ID: #{forwarded_message["message_id"]})")
              {:error, error} ->
                IO.puts("❌ Failed to forward message: #{inspect(error)}")
            end

            # Copy the message
            case TelegramBotLens.copy_message(chat_id, chat_id, forward_id) do
              {:ok, copied_message} ->
                IO.puts("✅ Message copied (ID: #{copied_message["message_id"]})")
              {:error, error} ->
                IO.puts("❌ Failed to copy message: #{inspect(error)}")
            end

          {:error, error} ->
            IO.puts("❌ Failed to send message to forward: #{inspect(error)}")
        end

        # Send a message to delete
        case TelegramBotLens.send_message(chat_id, "Message to be deleted") do
          {:ok, delete_message} ->
            delete_id = delete_message["message_id"]

            # Delete the message
            case TelegramBotLens.delete_message(chat_id, delete_id) do
              {:ok, true} ->
                IO.puts("✅ Message deleted (ID: #{delete_id})")
              {:error, error} ->
                IO.puts("❌ Failed to delete message: #{inspect(error)}")
            end

          {:error, error} ->
            IO.puts("❌ Failed to send message to delete: #{inspect(error)}")
        end

      {:error, error} ->
        IO.puts("❌ Failed to send original message: #{inspect(error)}")
    end
  end

  # Demonstrate chat management
  defp demonstrate_chat_management(chat_id) do
    IO.puts("\n👥 Demonstrating Chat Management...")

    # Get chat information
    case TelegramBotLens.get_chat(chat_id) do
      {:ok, chat_info} ->
        IO.puts("✅ Chat information retrieved:")
        IO.puts("  Type: #{chat_info["type"]}")
        if chat_info["title"], do: IO.puts("  Title: #{chat_info["title"]}")
        if chat_info["username"], do: IO.puts("  Username: @#{chat_info["username"]}")
      {:error, error} ->
        IO.puts("❌ Failed to get chat information: #{inspect(error)}")
    end

    # Get chat member count (for groups)
    case TelegramBotLens.get_chat_member_count(chat_id) do
      {:ok, count} ->
        IO.puts("✅ Chat member count: #{count}")
      {:error, error} ->
        IO.puts("❌ Failed to get member count: #{inspect(error)}")
    end

    # Get bot's member information
    case TelegramBotLens.get_me() do
      {:ok, bot_info} ->
        case TelegramBotLens.get_chat_member(chat_id, bot_info["id"]) do
          {:ok, member_info} ->
            IO.puts("✅ Bot's member information retrieved:")
            IO.puts("  Status: #{member_info["status"]}")
          {:error, error} ->
            IO.puts("❌ Failed to get bot's member information: #{inspect(error)}")
        end
      {:error, error} ->
        IO.puts("❌ Failed to get bot information: #{inspect(error)}")
    end
  end

  # Demonstrate webhook management
  defp demonstrate_webhook_management(webhook_url) do
    IO.puts("\n🔗 Demonstrating Webhook Management...")

    # Get current webhook info
    case TelegramBotLens.get_webhook_info() do
      {:ok, info} ->
        IO.puts("Current webhook info:")
        IO.puts("  URL: #{info["url"]}")
        IO.puts("  Has custom certificate: #{info["has_custom_certificate"]}")
        IO.puts("  Pending update count: #{info["pending_update_count"]}")

        # Set new webhook
        case TelegramBotLens.set_webhook(webhook_url, %{
          max_connections: 40,
          allowed_updates: ["message", "callback_query"]
        }) do
          {:ok, true} ->
            IO.puts("✅ Webhook set successfully")

            # Delete webhook
            case TelegramBotLens.delete_webhook(%{drop_pending_updates: true}) do
              {:ok, true} ->
                IO.puts("✅ Webhook deleted successfully")
              {:error, error} ->
                IO.puts("❌ Failed to delete webhook: #{inspect(error)}")
            end

          {:error, error} ->
            IO.puts("❌ Failed to set webhook: #{inspect(error)}")
        end

      {:error, error} ->
        IO.puts("❌ Failed to get webhook info: #{inspect(error)}")
    end
  end
end
