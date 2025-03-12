defmodule Lux.Lenses.Telegram.SendPhoto do
  @moduledoc """
  Lens for sending photos via the Telegram Bot API.

  This lens provides functionality to send photos to Telegram chats.
  It includes rate limiting and error handling with retry mechanisms.

  ## Example

  ```elixir
  alias Lux.Lenses.Telegram.SendPhoto

  # Send a photo by URL
  SendPhoto.focus(%{
    chat_id: 123456789,
    photo: "https://example.com/photo.jpg",
    caption: "A beautiful photo"
  })

  # Send a photo with markdown formatting in caption
  SendPhoto.focus(%{
    chat_id: 123456789,
    photo: "https://example.com/photo.jpg",
    caption: "*Bold* and _italic_ caption",
    parse_mode: "Markdown"
  })

  # Send a photo with additional options
  SendPhoto.send_photo(%{
    chat_id: 123456789,
    photo: "https://example.com/photo.jpg",
    caption: "Photo with options",
    disable_notification: true
  }, [max_retries: 5, initial_delay: 2000])
  ```
  """

  use Lux.Lens,
    name: "Telegram Send Photo API",
    description: "Sends photos via the Telegram Bot API",
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
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        photo: %{
          type: :string,
          description: "Photo to send. Pass a file_id as String to send a photo that exists on the Telegram servers, or pass an HTTP URL as a String for Telegram to get a photo from the Internet"
        },
        caption: %{
          type: :string,
          description: "Photo caption, 0-1024 characters after entities parsing"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the photo caption",
          enum: ["Markdown", "MarkdownV2", "HTML"]
        },
        caption_entities: %{
          type: :array,
          description: "A JSON-serialized list of special entities that appear in the caption"
        },
        disable_notification: %{
          type: :boolean,
          description: "Sends the message silently. Users will receive a notification with no sound"
        },
        protect_content: %{
          type: :boolean,
          description: "Protects the contents of the sent message from forwarding and saving"
        },
        reply_to_message_id: %{
          type: :integer,
          description: "If the message is a reply, ID of the original message"
        },
        allow_sending_without_reply: %{
          type: :boolean,
          description: "Pass True if the message should be sent even if the specified replied-to message is not found"
        },
        reply_markup: %{
          type: :object,
          description: "Additional interface options. A JSON-serialized object for an inline keyboard, custom reply keyboard, instructions to remove reply keyboard or to force a reply from the user"
        }
      },
      required: ["chat_id", "photo"]
    }

  alias Lux.Lenses.Telegram.TelegramAPIHandler

  @doc """
  Adds the bot token to the URL and appends the sendPhoto method.
  """
  def add_bot_token(lens) do
    token = Lux.Config.telegram_bot_token()
    url = lens.url <> token <> "/sendPhoto"
    %{lens | url: url}
  end

  @doc """
  Transforms the API response into a more usable format.

  ## Examples

      iex> after_focus(%{"ok" => true, "result" => %{"message_id" => 123}})
      {:ok, %{message_id: 123, ...}}

      iex> after_focus(%{"ok" => false, "description" => "Bad Request"})
      {:error, "Bad Request"}
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => result}) when is_map(result) do
    # Transform the result to a more Elixir-friendly format with atom keys
    transformed_result = %{
      message_id: result["message_id"],
      from: result["from"],
      chat: result["chat"],
      date: result["date"],
      photo: result["photo"],
      caption: result["caption"]
    }

    {:ok, transformed_result}
  end

  @impl true
  def after_focus(%{"ok" => false, "description" => description}) do
    # Return just the description string to match test expectations
    {:error, description}
  end

  @impl true
  def after_focus(response) do
    {:error, response}
  end

  @doc """
  Sends a photo with rate limiting and error handling.

  ## Parameters

  - `params`: The parameters for the message
  - `opts`: Options for rate limiting and retries
    - `max_retries`: Maximum number of retry attempts (default: 3)
    - `initial_delay`: Initial delay in milliseconds (default: 1000)
    - `max_delay`: Maximum delay in milliseconds (default: 30000)
    - `skip_rate_limit`: Skip rate limiting (default: false)
    - `skip_retries`: Skip retry logic (default: false)

  ## Returns

  Returns `{:ok, result}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> send_photo(%{chat_id: 123456789, photo: "https://example.com/photo.jpg"})
      {:ok, %{message_id: 42, ...}}

      iex> send_photo(%{chat_id: 123456789, photo: "https://example.com/photo.jpg"}, [max_retries: 5])
      {:ok, %{message_id: 42, ...}}
  """
  def send_photo(params, opts \\ []) do
    TelegramAPIHandler.request_with_handling(__MODULE__, params, opts)
  end

  defoverridable [focus: 2]

  @doc """
  Focuses the lens with the given input, applying rate limiting and error handling.

  This overrides the default focus implementation from Lux.Lens to automatically
  apply rate limiting and error handling via TelegramAPIHandler.

  ## Parameters

  - `input`: The parameters for the message
  - `opts`: Options for rate limiting and retries
    - `max_retries`: Maximum number of retry attempts (default: 3)
    - `initial_delay`: Initial delay in milliseconds (default: 1000)
    - `max_delay`: Maximum delay in milliseconds (default: 30000)
    - `skip_rate_limit`: Skip rate limiting (default: false)
    - `skip_retries`: Skip retry logic (default: false)

  ## Returns

  Returns `{:ok, result}` on success or `{:error, reason}` on failure.
  """
  def focus(input, opts) when is_map(input) do
    # Check if rate limiting should be skipped
    skip_rate_limit = Keyword.get(opts, :skip_rate_limit, false)

    if skip_rate_limit do
      # Call the original Lux.Lens implementation directly
      do_original_focus(input, opts)
    else
      # Use TelegramAPIHandler for rate limiting and error handling
      TelegramAPIHandler.request_with_handling(
        __MODULE__,
        input,
        Keyword.put(opts, :direct_focus_fn, &do_original_focus/2)
      )
    end
  end

  # Private function to call the original Lux.Lens focus implementation
  defp do_original_focus(input, opts) do
    __MODULE__.view()
    |> Map.update!(:params, &Map.merge(&1, input))
    |> Lux.Lens.authenticate()
    |> Map.update!(:params, &before_focus(&1))
    |> Lux.Lens.focus(opts)
  end
end
