defmodule Lux.Lenses.Telegram.SendMessage do
  @moduledoc """
  Lens for sending messages via the Telegram Bot API.

  This lens provides functionality to send text messages to Telegram chats.
  It includes rate limiting and error handling with retry mechanisms.

  ## Example

  ```elixir
  alias Lux.Lenses.Telegram.SendMessage

  # Send a simple message
  SendMessage.focus(%{
    chat_id: 123456789,
    text: "Hello from Lux!"
  })

  # Send a message with markdown formatting
  SendMessage.focus(%{
    chat_id: 123456789,
    text: "*Bold* and _italic_ text",
    parse_mode: "Markdown"
  })

  # Send a message with rate limiting and retry options
  SendMessage.send_message(%{
    chat_id: 123456789,
    text: "Hello with custom options!"
  }, [max_retries: 5, initial_delay: 2000])
  ```
  """

  use Lux.Lens,
    name: "Telegram Send Message API",
    description: "Sends text messages via the Telegram Bot API",
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
        text: %{
          type: :string,
          description: "Text of the message to be sent"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the message text",
          enum: ["Markdown", "MarkdownV2", "HTML"]
        },
        disable_web_page_preview: %{
          type: :boolean,
          description: "Disables link previews for links in this message"
        },
        disable_notification: %{
          type: :boolean,
          description: "Sends the message silently. Users will receive a notification with no sound."
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
        }
      },
      required: ["chat_id", "text"]
    }

  alias Lux.Lenses.Telegram.TelegramAPIHandler

  @doc """
  Adds the bot token to the URL and appends the sendMessage method.
  """
  def add_bot_token(lens) do
    token = Lux.Config.telegram_bot_token()
    url = lens.url <> token <> "/sendMessage"
    %{lens | url: url}
  end

  @doc """
  Transforms the API response into a more usable format.

  ## Examples

      iex> after_focus(%{"ok" => true, "result" => %{"message_id" => 123}})
      {:ok, %{message_id: 123, ...}}

      iex> after_focus(%{"ok" => false, "description" => "Bad Request"})
      {:error, %{"description" => "Bad Request"}}
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    # Transform the result to a more Elixir-friendly format with atom keys
    transformed_result = %{
      message_id: result["message_id"],
      from: result["from"],
      chat: result["chat"],
      date: result["date"],
      text: result["text"]
    }

    {:ok, transformed_result}
  end

  @impl true
  def after_focus(%{"ok" => false, "description" => description} = error) do
    # Return just the description string to match test expectations
    {:error, description}
  end

  @impl true
  def after_focus(response) do
    {:error, response}
  end

  @doc """
  Sends a message with rate limiting and error handling.

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

      iex> send_message(%{chat_id: 123456789, text: "Hello!"})
      {:ok, %{message_id: 123, ...}}

      iex> send_message(%{chat_id: 123456789, text: "Hello!"}, [max_retries: 5])
      {:ok, %{message_id: 123, ...}}
  """
  def send_message(params, opts \\ []) do
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
  def focus(input, opts \\ [])
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
