defmodule Lux.Lenses.TelegramBotLens do
  @moduledoc """
  Lens for interacting with the Telegram Bot API.

  This lens provides core functionality for Telegram Bot API integration,
  enabling secure bot communication and management.

  ## Features

  - Bot authentication and management
  - Message handling (send, receive, edit, delete)
  - Media file handling (photos, documents, voice messages)
  - Webhook integration and updates handling
  - Rate limit management
  - Error handling and retry mechanisms

  For interactive features like polls, games, live location, stickers, and inline queries,
  see `Lux.Lenses.TelegramInteractiveFeatures`.

  ## Example

  ```elixir
  alias Lux.Lenses.TelegramBotLens

  # Get bot information
  TelegramBotLens.focus(%{
    method: "getMe"
  })

  # Send a message
  TelegramBotLens.focus(%{
    method: "sendMessage",
    chat_id: 123_456_789,
    text: "Hello from Lux!"
  })

  # Send a photo
  TelegramBotLens.focus(%{
    method: "sendPhoto",
    chat_id: 123_456_789,
    photo: "https://example.com/image.jpg",
    caption: "Check out this photo!"
  })

  # Send a document
  TelegramBotLens.focus(%{
    method: "sendDocument",
    chat_id: 123_456_789,
    document: "https://example.com/file.pdf",
    caption: "Here's the document you requested"
  })
  ```
  """

  use Lux.Lens,
    name: "Telegram Bot API",
    description: "Interacts with the Telegram Bot API",
    url: "https://api.telegram.org/bot",
    method: :post,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &__MODULE__.add_bot_token/1
    },
    schema: %{
      type: :object,
      properties: %{
        method: %{
          type: :string,
          description: "Telegram Bot API method to call",
          enum: [
            # Bot information
            "getMe",
            "getUpdates",
            "setWebhook",
            "deleteWebhook",
            "getWebhookInfo",

            # Messaging
            "sendMessage",
            "forwardMessage",
            "copyMessage",
            "editMessageText",
            "editMessageCaption",
            "deleteMessage",

            # Media
            "sendPhoto",
            "sendAudio",
            "sendDocument",
            "sendVideo",
            "sendAnimation",
            "sendVoice",
            "sendVideoNote",
            "sendMediaGroup",

            # Interactive elements
            "sendLocation",
            "sendVenue",
            "sendContact",
            "sendDice",

            # Chat management
            "getChat",
            "getChatAdministrators",
            "getChatMemberCount",
            "getChatMember",
            "setChatTitle",
            "setChatDescription",
            "setChatPhoto",
            "deleteChatPhoto",
            "pinChatMessage",
            "unpinChatMessage",
            "unpinAllChatMessages",
            "leaveChat"
          ]
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        text: %{
          type: :string,
          description: "Text of the message to be sent"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the message text",
          enum: ["Markdown", "MarkdownV2", "HTML"]
        },
        photo: %{
          type: :string,
          description: "Photo to send (file_id, URL, or file path)"
        },
        document: %{
          type: :string,
          description: "Document to send (file_id, URL, or file path)"
        },
        video: %{
          type: :string,
          description: "Video to send (file_id, URL, or file path)"
        },
        audio: %{
          type: :string,
          description: "Audio to send (file_id, URL, or file path)"
        },
        caption: %{
          type: :string,
          description: "Caption for media messages"
        },
        reply_to_message_id: %{
          type: :integer,
          description: "If the message is a reply, ID of the original message"
        },
        reply_markup: %{
          type: :object,
          description: "Additional interface options (inline keyboard, custom reply keyboard, etc.)"
        }
      },
      required: ["method"]
    }

  alias Lux.Lenses.Telegram.Client

  @doc """
  Adds the bot token to the URL.
  """
  def add_bot_token(lens) do
    token = Lux.Config.telegram_bot_token()

    # Extract method from params if available
    method = Map.get(lens.params, "method") || Map.get(lens.params, :method)

    # Build the URL with the token and method
    url = lens.url <> token <> "/"
    url = if method, do: url <> method, else: url

    %{lens | url: url}
  end

  @doc """
  Prepares the parameters for the API request.
  """
  def before_focus(params) do
    # Get the method from the params
    _method = Map.get(params, :method)

    # Merge the params with the lens params
    params
    |> Map.merge(%{
      url: "https://api.telegram.org/bot#{params.token}/#{params.method}"
    })
  end

  @doc """
  Makes a request to the Telegram Bot API with rate limiting and error handling.

  This function overrides the default focus implementation to add rate limiting and error handling.
  """
  def telegram_request(input, opts \\ []) do
    # Create a lens with the input parameters
    lens = %Lens{
      url: "https://api.telegram.org/bot#{input.token}/#{input.method}",
      method: :post,
      headers: [{"content-type", "application/json"}],
      params: Map.drop(input, [:token])
    }

    # Make the request with rate limiting and error handling
    case Client.request(lens, lens.params, opts) do
      {:ok, %{"ok" => true, "result" => true}} -> {:ok, true}
      other -> other
    end
  end

  @doc """
  Gets information about the bot.
  """
  def get_me do
    telegram_request(%{method: "getMe", token: Lux.Config.telegram_bot_token()})
  end

  @doc """
  Sends a text message to a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat or username of the target channel
  - `text`: Text of the message to be sent
  - `opts`: Additional options for the message (parse_mode, disable_notification, etc.)

  ## Returns

  Returns the sent message on success.
  """
  def send_message(chat_id, text, opts \\ %{}) do
    telegram_request(
      Map.merge(
        %{
          method: "sendMessage",
          chat_id: chat_id,
          text: text,
          token: Lux.Config.telegram_bot_token()
        },
        opts
      )
    )
  end

  @doc """
  Sends a photo to a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat or username of the target channel
  - `photo`: Photo to send (file_id, URL, or file path)
  - `opts`: Additional options for the message (caption, parse_mode, etc.)

  ## Returns

  Returns the sent message on success.
  """
  def send_photo(chat_id, photo, opts \\ %{}) do
    telegram_request(
      Map.merge(
        %{
          method: "sendPhoto",
          chat_id: chat_id,
          photo: photo,
          token: Lux.Config.telegram_bot_token()
        },
        opts
      )
    )
  end

  @doc """
  Sends a document to a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat or username of the target channel
  - `document`: Document to send (file_id, URL, or file path)
  - `opts`: Additional options for the message (caption, parse_mode, etc.)

  ## Returns

  Returns the sent message on success.
  """
  def send_document(chat_id, document, opts \\ %{}) do
    telegram_request(
      Map.merge(
        %{
          method: "sendDocument",
          chat_id: chat_id,
          document: document,
          token: Lux.Config.telegram_bot_token()
        },
        opts
      )
    )
  end

  @doc """
  Sends a video to a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat or username of the target channel
  - `video`: Video to send (file_id, URL, or file path)
  - `opts`: Additional options for the message (caption, parse_mode, etc.)

  ## Returns

  Returns the sent message on success.
  """
  def send_video(chat_id, video, opts \\ %{}) do
    telegram_request(
      Map.merge(
        %{
          method: "sendVideo",
          chat_id: chat_id,
          video: video,
          token: Lux.Config.telegram_bot_token()
        },
        opts
      )
    )
  end

  @doc """
  Sends an audio file to a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat or username of the target channel
  - `audio`: Audio file to send (file_id, URL, or file path)
  - `opts`: Additional options for the message (caption, parse_mode, etc.)

  ## Returns

  Returns the sent message on success.
  """
  def send_audio(chat_id, audio, opts \\ %{}) do
    telegram_request(
      Map.merge(
        %{
          method: "sendAudio",
          chat_id: chat_id,
          audio: audio,
          token: Lux.Config.telegram_bot_token()
        },
        opts
      )
    )
  end

  @doc """
  Sends a location to a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat or username of the target channel
  - `latitude`: Latitude of the location
  - `longitude`: Longitude of the location
  - `opts`: Additional options for the message (live_period, etc.)

  ## Returns

  Returns the sent message on success.
  """
  def send_location(chat_id, latitude, longitude, opts \\ %{}) do
    telegram_request(
      Map.merge(
        %{
          method: "sendLocation",
          chat_id: chat_id,
          latitude: latitude,
          longitude: longitude,
          token: Lux.Config.telegram_bot_token()
        },
        opts
      )
    )
  end

  @doc """
  Gets information about the current webhook.
  """
  def get_webhook_info do
    telegram_request(%{method: "getWebhookInfo", token: Lux.Config.telegram_bot_token()})
  end

  @doc """
  Gets updates from the Telegram Bot API.

  ## Parameters

  - `opts`: Options for getting updates (offset, limit, timeout, etc.)

  ## Returns

  Returns an array of Update objects.
  """
  def get_updates(opts \\ %{}) do
    telegram_request(
      Map.merge(
        %{
          method: "getUpdates",
          token: Lux.Config.telegram_bot_token()
        },
        opts
      )
    )
  end

  @doc """
  Sends a media group to a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat or username of the target channel
  - `media`: Array of InputMedia objects (photos, videos, etc.)
  - `opts`: Additional options for the message (disable_notification, etc.)

  ## Returns

  Returns an array of sent messages on success.
  """
  def send_media_group(chat_id, media, opts \\ %{}) do
    telegram_request(
      Map.merge(
        %{
          method: "sendMediaGroup",
          chat_id: chat_id,
          media: media,
          token: Lux.Config.telegram_bot_token()
        },
        opts
      )
    )
  end

  @doc """
  Sends a voice message to a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat or username of the target channel
  - `voice`: Voice message to send (file_id, URL, or file path)
  - `opts`: Additional options for the message (caption, parse_mode, etc.)

  ## Returns

  Returns the sent message on success.
  """
  def send_voice(chat_id, voice, opts \\ %{}) do
    telegram_request(
      Map.merge(
        %{
          method: "sendVoice",
          chat_id: chat_id,
          voice: voice,
          token: Lux.Config.telegram_bot_token()
        },
        opts
      )
    )
  end

  @doc """
  Sends an animation to a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat or username of the target channel
  - `animation`: Animation to send (file_id, URL, or file path)
  - `opts`: Additional options for the message (caption, parse_mode, etc.)

  ## Returns

  Returns the sent message on success.
  """
  def send_animation(chat_id, animation, opts \\ %{}) do
    telegram_request(
      Map.merge(
        %{
          method: "sendAnimation",
          chat_id: chat_id,
          animation: animation,
          token: Lux.Config.telegram_bot_token()
        },
        opts
      )
    )
  end

  @doc """
  Sends a contact to a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat or username of the target channel
  - `phone_number`: Contact's phone number
  - `first_name`: Contact's first name
  - `opts`: Additional options for the contact (last_name, vcard, etc.)

  ## Returns

  Returns the sent message on success.
  """
  def send_contact(chat_id, phone_number, first_name, opts \\ %{}) do
    telegram_request(
      Map.merge(
        %{
          method: "sendContact",
          chat_id: chat_id,
          phone_number: phone_number,
          first_name: first_name,
          token: Lux.Config.telegram_bot_token()
        },
        opts
      )
    )
  end

  @doc """
  Edits a text message.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat or username of the target channel
  - `message_id`: Identifier of the message to edit
  - `text`: New text of the message
  - `opts`: Additional options for the message (parse_mode, etc.)

  ## Returns

  Returns the edited message on success.
  """
  def edit_message_text(chat_id, message_id, text, opts \\ %{}) do
    telegram_request(
      Map.merge(
        %{
          method: "editMessageText",
          chat_id: chat_id,
          message_id: message_id,
          text: text,
          token: Lux.Config.telegram_bot_token()
        },
        opts
      )
    )
  end

  @doc """
  Edits a message caption.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat or username of the target channel
  - `message_id`: Identifier of the message to edit
  - `caption`: New caption of the message
  - `opts`: Additional options for the message (parse_mode, etc.)

  ## Returns

  Returns the edited message on success.
  """
  def edit_message_caption(chat_id, message_id, caption, opts \\ %{}) do
    telegram_request(
      Map.merge(
        %{
          method: "editMessageCaption",
          chat_id: chat_id,
          message_id: message_id,
          caption: caption,
          token: Lux.Config.telegram_bot_token()
        },
        opts
      )
    )
  end

  @doc """
  Forwards a message.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat or username of the target channel
  - `from_chat_id`: Unique identifier for the chat where the original message was sent
  - `message_id`: Message identifier in the chat specified in from_chat_id
  - `opts`: Additional options for the message (disable_notification, etc.)

  ## Returns

  Returns the forwarded message on success.
  """
  def forward_message(chat_id, from_chat_id, message_id, opts \\ %{}) do
    telegram_request(
      Map.merge(
        %{
          method: "forwardMessage",
          chat_id: chat_id,
          from_chat_id: from_chat_id,
          message_id: message_id,
          token: Lux.Config.telegram_bot_token()
        },
        opts
      )
    )
  end

  @doc """
  Copies a message.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat or username of the target channel
  - `from_chat_id`: Unique identifier for the chat where the original message was sent
  - `message_id`: Message identifier in the chat specified in from_chat_id
  - `opts`: Additional options for the message (caption, parse_mode, etc.)

  ## Returns

  Returns the MessageId of the sent message on success.
  """
  def copy_message(chat_id, from_chat_id, message_id, opts \\ %{}) do
    telegram_request(
      Map.merge(
        %{
          method: "copyMessage",
          chat_id: chat_id,
          from_chat_id: from_chat_id,
          message_id: message_id,
          token: Lux.Config.telegram_bot_token()
        },
        opts
      )
    )
  end

  @doc """
  Deletes a message.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat or username of the target channel
  - `message_id`: Identifier of the message to delete

  ## Returns

  Returns true on success.
  """
  def delete_message(chat_id, message_id) do
    telegram_request(
      %{
        method: "deleteMessage",
        chat_id: chat_id,
        message_id: message_id,
        token: Lux.Config.telegram_bot_token()
      }
    )
  end

  @doc """
  Gets information about a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat or username of the target channel

  ## Returns

  Returns a Chat object on success.
  """
  def get_chat(chat_id) do
    telegram_request(
      %{
        method: "getChat",
        chat_id: chat_id,
        token: Lux.Config.telegram_bot_token()
      }
    )
  end

  @doc """
  Gets the number of members in a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat or username of the target channel

  ## Returns

  Returns the number of members in the chat on success.
  """
  def get_chat_member_count(chat_id) do
    telegram_request(
      %{
        method: "getChatMemberCount",
        chat_id: chat_id,
        token: Lux.Config.telegram_bot_token()
      }
    )
  end

  @doc """
  Gets information about a member of a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat or username of the target channel
  - `user_id`: Unique identifier of the target user

  ## Returns

  Returns a ChatMember object on success.
  """
  def get_chat_member(chat_id, user_id) do
    telegram_request(
      %{
        method: "getChatMember",
        chat_id: chat_id,
        user_id: user_id,
        token: Lux.Config.telegram_bot_token()
      }
    )
  end

  @doc """
  Sends a dice to a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat or username of the target channel
  - `opts`: Additional options for the message (emoji, disable_notification, etc.)

  ## Returns

  Returns the sent message on success.
  """
  def send_dice(chat_id, opts \\ %{}) do
    telegram_request(
      Map.merge(
        %{
          method: "sendDice",
          chat_id: chat_id,
          token: Lux.Config.telegram_bot_token()
        },
        opts
      )
    )
  end

  @doc """
  Sends a venue to a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat or username of the target channel
  - `latitude`: Latitude of the venue
  - `longitude`: Longitude of the venue
  - `title`: Name of the venue
  - `address`: Address of the venue
  - `opts`: Additional options for the message (foursquare_id, etc.)

  ## Returns

  Returns the sent message on success.
  """
  def send_venue(chat_id, latitude, longitude, title, address, opts \\ %{}) do
    telegram_request(
      Map.merge(
        %{
          method: "sendVenue",
          chat_id: chat_id,
          latitude: latitude,
          longitude: longitude,
          title: title,
          address: address,
          token: Lux.Config.telegram_bot_token()
        },
        opts
      )
    )
  end

  @doc """
  Process an update received from Telegram.

  This function takes an update object (from webhook or getUpdates) and extracts
  the relevant information based on the update type.

  ## Parameters

  - `update`: The update object received from Telegram

  ## Returns

  Returns a map with the processed update information, categorized by type:
  - `:message` - Regular text messages
  - `:edited_message` - Edited messages
  - `:channel_post` - Channel posts
  - `:edited_channel_post` - Edited channel posts
  - `:callback_query` - Callback queries from inline keyboards
  - `:poll` - Poll updates
  - `:poll_answer` - Poll answer updates

  Each type contains the relevant data extracted from the update.
  """
  def process_update(update) when is_map(update) do
    cond do
      Map.has_key?(update, "message") ->
        message = update["message"]
        %{
          type: :message,
          update_id: update["update_id"],
          message_id: message["message_id"],
          from: message["from"],
          chat: message["chat"],
          date: message["date"],
          text: message["text"],
          entities: message["entities"],
          raw: message
        }

      Map.has_key?(update, "edited_message") ->
        message = update["edited_message"]
        %{
          type: :edited_message,
          update_id: update["update_id"],
          message_id: message["message_id"],
          from: message["from"],
          chat: message["chat"],
          date: message["date"],
          edit_date: message["edit_date"],
          text: message["text"],
          entities: message["entities"],
          raw: message
        }

      Map.has_key?(update, "channel_post") ->
        post = update["channel_post"]
        %{
          type: :channel_post,
          update_id: update["update_id"],
          message_id: post["message_id"],
          chat: post["chat"],
          date: post["date"],
          text: post["text"],
          entities: post["entities"],
          raw: post
        }

      Map.has_key?(update, "edited_channel_post") ->
        post = update["edited_channel_post"]
        %{
          type: :edited_channel_post,
          update_id: update["update_id"],
          message_id: post["message_id"],
          chat: post["chat"],
          date: post["date"],
          edit_date: post["edit_date"],
          text: post["text"],
          entities: post["entities"],
          raw: post
        }

      Map.has_key?(update, "callback_query") ->
        query = update["callback_query"]
        %{
          type: :callback_query,
          update_id: update["update_id"],
          id: query["id"],
          from: query["from"],
          message: query["message"],
          chat_instance: query["chat_instance"],
          data: query["data"],
          raw: query
        }

      Map.has_key?(update, "poll") ->
        poll = update["poll"]
        %{
          type: :poll,
          update_id: update["update_id"],
          id: poll["id"],
          question: poll["question"],
          options: poll["options"],
          total_voter_count: poll["total_voter_count"],
          is_closed: poll["is_closed"],
          is_anonymous: poll["is_anonymous"],
          raw: poll
        }

      Map.has_key?(update, "poll_answer") ->
        answer = update["poll_answer"]
        %{
          type: :poll_answer,
          update_id: update["update_id"],
          poll_id: answer["poll_id"],
          user: answer["user"],
          option_ids: answer["option_ids"],
          raw: answer
        }

      true ->
        %{
          type: :unknown,
          update_id: update["update_id"],
          raw: update
        }
    end
  end

  @doc """
  Process multiple updates received from Telegram.

  ## Parameters

  - `updates`: A list of update objects received from Telegram

  ## Returns

  Returns a list of processed updates.
  """
  def process_updates(updates) when is_list(updates) do
    Enum.map(updates, &process_update/1)
  end

  @doc """
  Gets updates from Telegram and processes them into a more usable format.

  ## Parameters

  - `opts`: Options for getting updates (offset, limit, timeout, etc.)

  ## Returns

  Returns a list of processed updates on success, or an error tuple.
  """
  def get_and_process_updates(opts \\ %{}) do
    case get_updates(opts) do
      {:ok, updates} -> {:ok, process_updates(updates)}
      error -> error
    end
  end

  @doc """
  Sets up a long polling mechanism to continuously receive updates.
  This is a simple implementation that will run in the current process.

  ## Parameters

  - `callback`: A function that will be called with each update
  - `opts`: Options for getting updates (limit, timeout, etc.)

  ## Returns

  This function runs indefinitely until an error occurs or it's interrupted.
  """
  def start_long_polling(callback, opts \\ %{}) when is_function(callback, 1) do
    # Start with no offset
    do_long_polling(callback, opts, nil)
  end

  defp do_long_polling(callback, opts, last_update_id) do
    # Add the offset to the options if we have a last update ID
    polling_opts = if last_update_id do
      Map.put(opts, :offset, last_update_id + 1)
    else
      opts
    end

    # Add a timeout if not specified (default to 30 seconds)
    polling_opts = Map.put_new(polling_opts, :timeout, 30)

    # Get updates
    case get_updates(polling_opts) do
      {:ok, []} ->
        # No updates, continue polling with the same last_update_id
        do_long_polling(callback, opts, last_update_id)

      {:ok, updates} ->
        # Process updates
        processed_updates = process_updates(updates)

        # Call the callback for each update
        Enum.each(processed_updates, callback)

        # Get the highest update_id
        new_last_update_id = updates
          |> Enum.map(& &1["update_id"])
          |> Enum.max(fn -> last_update_id end)

        # Continue polling with the new last_update_id
        do_long_polling(callback, opts, new_last_update_id)

      {:error, error} ->
        # Log the error and retry after a delay
        IO.puts("Error in long polling: #{inspect(error)}")
        :timer.sleep(5000)
        do_long_polling(callback, opts, last_update_id)
    end
  end

  @doc """
  Waits for a specific message or update that matches the given filter function.
  This is useful for integration testing or interactive scenarios.

  ## Parameters

  - `filter_fn`: A function that takes a processed update and returns true if it matches
  - `timeout_ms`: Maximum time to wait in milliseconds (default: 30_000)
  - `opts`: Options for getting updates (limit, etc.)

  ## Returns

  Returns `{:ok, update}` if a matching update is found within the timeout,
  or `{:error, :timeout}` if the timeout is reached.
  """
  def wait_for_update(filter_fn, timeout_ms \\ 30_000, opts \\ %{}) when is_function(filter_fn, 1) do
    # Record the start time
    start_time = System.monotonic_time(:millisecond)

    # Start with no offset
    wait_for_update_loop(filter_fn, timeout_ms, start_time, opts, nil)
  end

  defp wait_for_update_loop(filter_fn, timeout_ms, start_time, opts, last_update_id) do
    # Check if we've exceeded the timeout
    current_time = System.monotonic_time(:millisecond)
    elapsed_time = current_time - start_time

    if elapsed_time >= timeout_ms do
      {:error, :timeout}
    else
      # Calculate remaining timeout
      remaining_timeout = timeout_ms - elapsed_time

      # Add the offset to the options if we have a last update ID
      polling_opts = if last_update_id do
        Map.put(opts, :offset, last_update_id + 1)
      else
        opts
      end

      # Use a shorter timeout for each API call (max 5 seconds)
      polling_opts = Map.put(polling_opts, :timeout, min(5, div(remaining_timeout, 1000)))

      # Get updates
      case get_updates(polling_opts) do
        {:ok, []} ->
          # No updates, continue polling with the same last_update_id
          wait_for_update_loop(filter_fn, timeout_ms, start_time, opts, last_update_id)

        {:ok, updates} ->
          # Process updates
          processed_updates = process_updates(updates)

          # Look for a matching update
          case Enum.find(processed_updates, filter_fn) do
            nil ->
              # No matching update, continue polling with the new last_update_id
              new_last_update_id = updates
                |> Enum.map(& &1["update_id"])
                |> Enum.max(fn -> last_update_id end)

              wait_for_update_loop(filter_fn, timeout_ms, start_time, opts, new_last_update_id)

            matching_update ->
              # Found a matching update
              {:ok, matching_update}
          end

        {:error, _error} ->
          # On error, wait a bit and retry
          :timer.sleep(1000)
          wait_for_update_loop(filter_fn, timeout_ms, start_time, opts, last_update_id)
      end
    end
  end

  @doc """
  Sets a webhook for receiving updates.

  ## Parameters

  - `url`: HTTPS URL to send updates to
  - `opts`: Additional options for the webhook (certificate, max_connections, etc.)

  ## Returns

  Returns True on success.

  ## Example

  ```elixir
  # Set a webhook with default options
  TelegramBotLens.set_webhook("https://example.com/webhook/secret-path")

  # Set a webhook with custom options
  TelegramBotLens.set_webhook("https://example.com/webhook/secret-path", %{
    max_connections: 40,
    allowed_updates: ["message", "callback_query"]
  })
  ```
  """
  def set_webhook(url, opts \\ %{}) do
    telegram_request(
      Map.merge(
        %{
          method: "setWebhook",
          url: url,
          token: Lux.Config.telegram_bot_token()
        },
        opts
      )
    )
  end

  @doc """
  Removes a webhook.

  ## Parameters

  - `opts`: Options for removing the webhook (drop_pending_updates)

  ## Returns

  Returns True on success.

  ## Example

  ```elixir
  # Remove webhook
  TelegramBotLens.delete_webhook()

  # Remove webhook and drop pending updates
  TelegramBotLens.delete_webhook(%{drop_pending_updates: true})
  ```
  """
  def delete_webhook(opts \\ %{}) do
    telegram_request(
      Map.merge(
        %{
          method: "deleteWebhook",
          token: Lux.Config.telegram_bot_token()
        },
        opts
      )
    )
  end

  @doc """
  Processes an update received from a webhook.

  This function should be called when an update is received from Telegram via webhook.
  It parses the update and returns it in a structured format.

  ## Parameters

  - `update`: The update JSON received from Telegram

  ## Returns

  Returns the parsed update.

  ## Example

  ```elixir
  # In your webhook handler
  def handle_webhook(conn) do
    update = conn.body_params
    processed_update = TelegramBotLens.process_webhook_update(update)
    # Process the update...
    send_resp(conn, 200, "")
  end
  ```
  """
  def process_webhook_update(update) do
    # Parse the update based on its type
    cond do
      Map.has_key?(update, "message") ->
        {:message, update["message"]}

      Map.has_key?(update, "edited_message") ->
        {:edited_message, update["edited_message"]}

      Map.has_key?(update, "channel_post") ->
        {:channel_post, update["channel_post"]}

      Map.has_key?(update, "edited_channel_post") ->
        {:edited_channel_post, update["edited_channel_post"]}

      Map.has_key?(update, "inline_query") ->
        {:inline_query, update["inline_query"]}

      Map.has_key?(update, "chosen_inline_result") ->
        {:chosen_inline_result, update["chosen_inline_result"]}

      Map.has_key?(update, "callback_query") ->
        {:callback_query, update["callback_query"]}

      Map.has_key?(update, "shipping_query") ->
        {:shipping_query, update["shipping_query"]}

      Map.has_key?(update, "pre_checkout_query") ->
        {:pre_checkout_query, update["pre_checkout_query"]}

      Map.has_key?(update, "poll") ->
        {:poll, update["poll"]}

      Map.has_key?(update, "poll_answer") ->
        {:poll_answer, update["poll_answer"]}

      Map.has_key?(update, "my_chat_member") ->
        {:my_chat_member, update["my_chat_member"]}

      Map.has_key?(update, "chat_member") ->
        {:chat_member, update["chat_member"]}

      Map.has_key?(update, "chat_join_request") ->
        {:chat_join_request, update["chat_join_request"]}

      true ->
        {:unknown, update}
    end
  end

  @doc """
  Creates a webhook server using Plug.

  This function returns a Plug module that can be used to handle webhook requests.
  It's designed to be used with Plug.Cowboy or any other Plug-compatible web server.

  ## Parameters

  - `handler`: A function that will be called with each update
  - `opts`: Options for the webhook server
    - `:path`: The path to listen on (default: "/webhook")
    - `:secret_token`: A secret token to validate requests (default: nil)

  ## Returns

  Returns a Plug module.

  ## Example

  ```elixir
  # Create a webhook handler
  defmodule MyApp.TelegramHandler do
    def handle_update({:message, message}) do
      # Process message
      chat_id = message["chat"]["id"]
      text = message["text"]

      if text do
        TelegramBotLens.send_message(chat_id, "You said: \#{text}")
      end
    end

    def handle_update(_), do: :ok
  end

  # Create and start the webhook server
  webhook_plug = TelegramBotLens.create_webhook_server(&MyApp.TelegramHandler.handle_update/1)

  # Start the server with Plug.Cowboy
  Plug.Cowboy.http(webhook_plug, [], port: 4000)

  # Set the webhook
  TelegramBotLens.set_webhook("https://example.com/webhook")
  ```
  """
  def create_webhook_server(handler, opts \\ []) do
    path = Keyword.get(opts, :path, "/webhook")
    secret_token = Keyword.get(opts, :secret_token)

    # Create a dynamic module that implements the Plug behaviour
    webhook_module = Module.concat(["Lux", "Lenses", "Telegram", "WebhookServer"])

    # Store the handler in a persistent term for the module to access
    :persistent_term.put({webhook_module, :handler}, handler)
    :persistent_term.put({webhook_module, :secret_token}, secret_token)
    :persistent_term.put({webhook_module, :path}, path)

    # Define the module
    module_definition = quote do
      @moduledoc """
      A Plug for handling Telegram webhook requests.
      """
      use Plug.Router

      plug Plug.Logger
      plug :match
      plug Plug.Parsers, parsers: [:json], json_decoder: Jason
      plug :dispatch

      # Get the path from persistent term
      @path :persistent_term.get({__MODULE__, :path})

      # Match the webhook path
      post @path do
        # Get the secret token from persistent term
        secret_token = :persistent_term.get({__MODULE__, :secret_token})

        # Validate the secret token if provided
        if secret_token do
          request_token = get_req_header(conn, "x-telegram-bot-api-secret-token") |> List.first()

          if request_token != secret_token do
            conn
            |> send_resp(403, "Forbidden")
            |> halt()
          end
        end

        # Process the update
        update = conn.body_params

        # Process the update in a separate process to avoid blocking
        spawn(fn ->
          # Get the handler from persistent term
          handler = :persistent_term.get({__MODULE__, :handler})
          processed_update = Lux.Lenses.TelegramBotLens.process_webhook_update(update)
          handler.(processed_update)
        end)

        # Respond with 200 OK immediately
        send_resp(conn, 200, "")
      end

      # Handle all other requests
      match _ do
        send_resp(conn, 404, "Not found")
      end
    end

    # Create the module
    Module.create(webhook_module, module_definition, Macro.Env.location(__ENV__))

    # Return the module
    webhook_module
  end

  @doc """
  Starts a webhook server using Plug.Cowboy.

  This is a convenience function that creates and starts a webhook server.

  ## Parameters

  - `handler`: A function that will be called with each update
  - `opts`: Options for the webhook server
    - `:path`: The path to listen on (default: "/webhook")
    - `:secret_token`: A secret token to validate requests (default: nil)
    - `:port`: The port to listen on (default: 4000)
    - `:scheme`: The scheme to use (:http or :https) (default: :http)
    - `:certfile`: Path to the certificate file for HTTPS
    - `:keyfile`: Path to the key file for HTTPS

  ## Returns

  Returns the result of Plug.Cowboy.http/3 or Plug.Cowboy.https/4.

  ## Example

  ```elixir
  # Define a handler function
  handler = fn
    {:message, message} ->
      # Process message
      chat_id = message["chat"]["id"]
      text = message["text"]

      if text do
        TelegramBotLens.send_message(chat_id, "You said: \#{text}")
      end

    _ -> :ok
  end

  # Start the webhook server
  {:ok, pid} = TelegramBotLens.start_webhook_server(handler, port: 8443)

  # Set the webhook
  TelegramBotLens.set_webhook("https://example.com:8443/webhook")
  ```
  """
  def start_webhook_server(handler, opts \\ []) do
    # Extract options
    path = Keyword.get(opts, :path, "/webhook")
    secret_token = Keyword.get(opts, :secret_token)
    port = Keyword.get(opts, :port, 4000)
    scheme = Keyword.get(opts, :scheme, :http)

    # Create the webhook server
    webhook_plug = create_webhook_server(handler, [path: path, secret_token: secret_token])

    # Start the server with Plug.Cowboy
    case scheme do
      :https ->
        certfile = Keyword.fetch!(opts, :certfile)
        keyfile = Keyword.fetch!(opts, :keyfile)

        Plug.Cowboy.https(webhook_plug, [], [
          port: port,
          certfile: certfile,
          keyfile: keyfile
        ])

      :http ->
        Plug.Cowboy.http(webhook_plug, [], port: port)
    end
  end

  @doc """
  Creates a simple echo bot webhook server.

  This is a convenience function that creates a webhook server that echoes back any message it receives.

  ## Parameters

  - `opts`: Options for the webhook server
    - `:path`: The path to listen on (default: "/webhook")
    - `:secret_token`: A secret token to validate requests (default: nil)
    - `:port`: The port to listen on (default: 4000)
    - `:scheme`: The scheme to use (:http or :https) (default: :http)
    - `:certfile`: Path to the certificate file for HTTPS
    - `:keyfile`: Path to the key file for HTTPS

  ## Returns

  Returns the result of start_webhook_server/2.

  ## Example

  ```elixir
  # Start an echo bot webhook server
  {:ok, pid} = TelegramBotLens.start_echo_webhook_server(port: 8443)

  # Set the webhook
  TelegramBotLens.set_webhook("https://example.com:8443/webhook")
  ```
  """
  def start_echo_webhook_server(opts \\ []) do
    # Define the echo handler
    echo_handler = fn
      {:message, message} ->
        # Get message details
        chat_id = message["chat"]["id"]

        # Check if the message has text
        if Map.has_key?(message, "text") do
          text = message["text"]
          # Echo the message back
          send_message(chat_id, "Echo: #{text}")
        end

      _ -> :ok
    end

    # Start the webhook server with the echo handler
    start_webhook_server(echo_handler, opts)
  end

  # Interactive features have been moved to Lux.Lenses.TelegramInteractiveFeatures
end
