defmodule Lux.Lenses.Telegram.CallbackLens do
  @moduledoc """
  Lens for answering Telegram inline keyboard callback queries via `/answerCallbackQuery`.
  """

  use Lux.Lens,
    name: "Telegram Callback Lens",
    description: "Sends responses and acknowledgments to Telegram inline button callback queries.",
    url: "https://api.telegram.org/bot/answerCallbackQuery",
    method: :post,
    headers: [{"Content-Type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Lux.Integrations.Telegram.add_auth_header/1
    },
    schema: %{
      type: :object,
      properties: %{
        callback_query_id: %{
          type: :string,
          description: "Unique identifier for the query to be answered."
        },
        text: %{
          type: :string,
          description: "Text of the notification. If not specified, nothing will be shown to the user."
        },
        show_alert: %{
          type: :boolean,
          description: "If True, an alert will be shown by the client instead of a notification at the top of the chat screen."
        },
        url: %{
          type: :string,
          description: "URL that will be opened by the user's client."
        },
        cache_time: %{
          type: :integer,
          description: "The maximum amount of time in seconds that the result of the callback query may be cached client-side."
        }
      },
      required: ["callback_query_id"]
    }

  @impl true
  def after_focus(%{"ok" => true, "result" => true}) do
    {:ok, %{answered: true}}
  end

  def after_focus(%{"ok" => false, "description" => desc}) do
    {:error, "Telegram API error: #{desc}"}
  end

  def after_focus(other), do: {:ok, other}
end
