defmodule Lux.Lenses.Telegram.ForwardMessage do
  @moduledoc """
  Lens for forwarding messages via the Telegram Bot API.

  This lens provides functionality to forward messages from one chat to another.
  It includes rate limiting and error handling with retry mechanisms.

  ## Example

  ```elixir
  alias Lux.Lenses.Telegram.ForwardMessage

  # Forward a message
  ForwardMessage.focus(%{
    chat_id: 123456789,
    from_chat_id: 987654321,
    message_id: 42
  })

  # Forward a message silently (without notification)
  ForwardMessage.focus(%{
    chat_id: 123456789,
    from_chat_id: 987654321,
    message_id: 42,
    disable_notification: true
  })

  # Forward a message with rate limiting and retry options
  ForwardMessage.forward_message(%{
    chat_id: 123456789,
    from_chat_id: 987654321,
    message_id: 42
  }, [max_retries: 5, initial_delay: 2000])
  ```
  """

  use Lux.Lens,
    name: "Telegram Forward Message API",
    description: "Forwards messages via the Telegram Bot API",
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
        from_chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the chat where the original message was sent"
        },
        message_id: %{
          type: :integer,
          description: "Message identifier in the chat specified in from_chat_id"
        },
        disable_notification: %{
          type: :boolean,
          description: "Sends the message silently. Users will receive a notification with no sound."
        },
        protect_content: %{
          type: :boolean,
          description: "Protects the contents of the forwarded message from forwarding and saving"
        }
      },
      required: ["chat_id", "from_chat_id", "message_id"]
    }

  alias Lux.Lenses.Telegram.TelegramAPIHandler

  @doc """
  Adds the bot token to the URL and appends the forwardMessage method.
  """
  def add_bot_token(lens) do
    token = Lux.Config.telegram_bot_token()
    url = lens.url <> token <> "/forwardMessage"
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
      forward_from: result["forward_from"],
      forward_from_chat: result["forward_from_chat"],
      forward_date: result["forward_date"],
      text: result["text"],
      caption: result["caption"]
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
  Forwards a message with rate limiting and error handling.

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

      iex> forward_message(%{chat_id: 123456789, from_chat_id: 987654321, message_id: 42})
      {:ok, %{message_id: 123, ...}}

      iex> forward_message(%{chat_id: 123456789, from_chat_id: 987654321, message_id: 42}, [max_retries: 5])
      {:ok, %{message_id: 123, ...}}
  """
  def forward_message(params, opts \\ []) do
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
