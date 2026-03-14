defmodule Lux.Lenses.Telegram.Keyboards.AnswerCallback do
  @moduledoc """
  A lens for answering callback queries via the Telegram Bot API.

  When a user presses an inline keyboard button with `callback_data`, Telegram
  sends a callback query to the bot. This lens sends a response to that query,
  optionally displaying a notification or alert to the user.

  ## Important

  Each callback query must be answered, even if no notification is needed.
  Otherwise, the user will see a loading indicator on the button.

  ## Examples

      # Simple acknowledgment (no visible notification)
      iex> AnswerCallback.focus(%{
      ...>   callback_query_id: "4382bfdwdsb323b2d9"
      ...> })
      {:ok, %{answered: true}}

      # Show a notification
      iex> AnswerCallback.focus(%{
      ...>   callback_query_id: "4382bfdwdsb323b2d9",
      ...>   text: "Option selected!"
      ...> })
      {:ok, %{answered: true}}

      # Show an alert dialog
      iex> AnswerCallback.focus(%{
      ...>   callback_query_id: "4382bfdwdsb323b2d9",
      ...>   text: "Are you sure?",
      ...>   show_alert: true
      ...> })
      {:ok, %{answered: true}}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Answer Telegram Callback Query",
    description: "Sends an answer to a callback query from an inline keyboard",
    url: Telegram.api_url("answerCallbackQuery"),
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        callback_query_id: %{
          type: :string,
          description: "Unique identifier for the query to be answered"
        },
        text: %{
          type: :string,
          description: "Text of the notification (0-200 characters). If not specified, nothing is shown."
        },
        show_alert: %{
          type: :boolean,
          description: "If true, show an alert dialog instead of a notification at the top of the chat screen"
        },
        url: %{
          type: :string,
          description: "URL that will be opened by the user's client"
        },
        cache_time: %{
          type: :integer,
          description: "Maximum time in seconds that the result of the callback query may be cached client-side (default 0)"
        }
      },
      required: ["callback_query_id"]
    }

  @doc """
  Transforms the Telegram API response into a clean format.
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => true}) do
    {:ok, %{answered: true}}
  end

  def after_focus(%{"ok" => false, "error_code" => 429, "parameters" => %{"retry_after" => retry_after}} = error) do
    {:error, %{
      reason: :rate_limited,
      retry_after: retry_after,
      description: error["description"]
    }}
  end

  def after_focus(%{"ok" => false, "description" => description, "error_code" => code}) do
    {:error, %{reason: :api_error, error_code: code, description: description}}
  end

  def after_focus(%{"description" => description}) do
    {:error, %{reason: :api_error, description: description}}
  end
end
