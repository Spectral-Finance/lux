defmodule Lux.Lenses.Telegram.Messaging.TelegramDeleteMessageLens do
  @moduledoc """
  Lens for deleting messages via the Telegram Bot API.

  This lens provides functionality to delete messages from Telegram chats.
  It includes rate limiting and error handling with retry mechanisms.

  ## Example

  ```elixir
  alias Lux.Lenses.Telegram.Messaging.TelegramDeleteMessageLens

  # Delete a message
  TelegramDeleteMessageLens.focus(%{
    chat_id: 123456789,
    message_id: 42
  })

  # Delete a message with rate limiting and retry options
  TelegramDeleteMessageLens.delete_message(%{
    chat_id: 123456789,
    message_id: 42
  }, [max_retries: 5, initial_delay: 2000])
  ```
  """

  use Lux.Lens,
    name: "Telegram Delete Message API",
    description: "Deletes messages via the Telegram Bot API",
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
        message_id: %{
          type: :integer,
          description: "Identifier of the message to delete"
        }
      },
      required: ["chat_id", "message_id"]
    }

  alias Lux.Lenses.Telegram.TelegramAPIHandler

  @doc """
  Adds the bot token to the URL and appends the deleteMessage method.
  """
  def add_bot_token(lens) do
    token = Lux.Config.telegram_bot_token()
    url = lens.url <> token <> "/deleteMessage"
    %{lens | url: url}
  end

  @doc """
  Transforms the API response into a more usable format.

  ## Examples

      iex> after_focus(%{"ok" => true, "result" => true})
      {:ok, true}

      iex> after_focus(%{"ok" => false, "description" => "Bad Request"})
      {:error, "Bad Request"}
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => true}) do
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
  Deletes a message with rate limiting and error handling.

  ## Parameters

  - `params`: The parameters for the message deletion
  - `opts`: Options for rate limiting and retries
    - `max_retries`: Maximum number of retry attempts (default: 3)
    - `initial_delay`: Initial delay in milliseconds (default: 1000)
    - `max_delay`: Maximum delay in milliseconds (default: 30000)
    - `skip_rate_limit`: Skip rate limiting (default: false)
    - `skip_retries`: Skip retry logic (default: false)

  ## Returns

  Returns `{:ok, true}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> delete_message(%{chat_id: 123456789, message_id: 42})
      {:ok, true}

      iex> delete_message(%{chat_id: 123456789, message_id: 42}, [max_retries: 5])
      {:ok, true}
  """
  def delete_message(params, opts \\ []) do
    TelegramAPIHandler.request_with_handling(__MODULE__, params, opts)
  end

  defoverridable [focus: 2]

  @doc """
  Focuses the lens with the given input, applying rate limiting and error handling.

  This overrides the default focus implementation from Lux.Lens to automatically
  apply rate limiting and error handling via TelegramAPIHandler.

  ## Parameters

  - `input`: The parameters for the message deletion
  - `opts`: Options for rate limiting and retries
    - `max_retries`: Maximum number of retry attempts (default: 3)
    - `initial_delay`: Initial delay in milliseconds (default: 1000)
    - `max_delay`: Maximum delay in milliseconds (default: 30000)
    - `skip_rate_limit`: Skip rate limiting (default: false)
    - `skip_retries`: Skip retry logic (default: false)

  ## Returns

  Returns `{:ok, true}` on success or `{:error, reason}` on failure.
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
