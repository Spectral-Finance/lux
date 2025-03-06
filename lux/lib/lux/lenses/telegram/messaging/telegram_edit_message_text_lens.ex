defmodule Lux.Lenses.Telegram.Messaging.TelegramEditMessageTextLens do
  @moduledoc """
  Lens for editing message text via the Telegram Bot API.

  This lens provides functionality to edit text messages in Telegram chats.
  It includes rate limiting and error handling with retry mechanisms.

  ## Example

  ```elixir
  alias Lux.Lenses.Telegram.Messaging.TelegramEditMessageTextLens

  # Edit a message text
  TelegramEditMessageTextLens.focus(%{
    chat_id: 123456789,
    message_id: 42,
    text: "Updated message text"
  })

  # Edit a message with markdown formatting
  TelegramEditMessageTextLens.focus(%{
    chat_id: 123456789,
    message_id: 42,
    text: "*Bold* and _italic_ text",
    parse_mode: "Markdown"
  })

  # Edit an inline message text
  TelegramEditMessageTextLens.focus(%{
    inline_message_id: "123456789",
    text: "Updated inline message text"
  })

  # Edit a message with rate limiting and retry options
  TelegramEditMessageTextLens.edit_message_text(%{
    chat_id: 123456789,
    message_id: 42,
    text: "Updated message text"
  }, [max_retries: 5, initial_delay: 2000])
  ```
  """

  use Lux.Lens,
    name: "Telegram Edit Message Text API",
    description: "Edits text messages via the Telegram Bot API",
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
          description: "Required if inline_message_id is not specified. Unique identifier for the target chat or username of the target channel"
        },
        message_id: %{
          type: :integer,
          description: "Required if inline_message_id is not specified. Identifier of the message to edit"
        },
        inline_message_id: %{
          type: :string,
          description: "Required if chat_id and message_id are not specified. Identifier of the inline message"
        },
        text: %{
          type: :string,
          description: "New text of the message, 1-4096 characters after entities parsing"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the message text",
          enum: ["Markdown", "MarkdownV2", "HTML"]
        },
        entities: %{
          type: :array,
          description: "A JSON-serialized list of special entities that appear in message text"
        },
        disable_web_page_preview: %{
          type: :boolean,
          description: "Disables link previews for links in this message"
        },
        reply_markup: %{
          type: :object,
          description: "A JSON-serialized object for an inline keyboard"
        }
      },
      required: ["text"]
    }

  alias Lux.Lenses.Telegram.TelegramAPIHandler

  @doc """
  Adds the bot token to the URL and appends the editMessageText method.
  """
  def add_bot_token(lens) do
    token = Lux.Config.telegram_bot_token()
    url = lens.url <> token <> "/editMessageText"
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
      edit_date: result["edit_date"],
      text: result["text"]
    }

    {:ok, transformed_result}
  end

  @impl true
  def after_focus(%{"ok" => true, "result" => true}) do
    # For inline message edits, the API returns just "result": true
    {:ok, true}
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
  Edits a message text with rate limiting and error handling.

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

      iex> edit_message_text(%{chat_id: 123456789, message_id: 42, text: "Updated text"})
      {:ok, %{message_id: 42, ...}}

      iex> edit_message_text(%{chat_id: 123456789, message_id: 42, text: "Updated text"}, [max_retries: 5])
      {:ok, %{message_id: 42, ...}}
  """
  def edit_message_text(params, opts \\ []) do
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
