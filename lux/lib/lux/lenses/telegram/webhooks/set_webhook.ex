defmodule Lux.Lenses.Telegram.Webhooks.SetWebhook do
  @moduledoc \"\"\"
  A lens for setting up a webhook for the Telegram Bot API.
  \"\"\"

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Set Telegram Webhook",
    description: "Specifies a url and receives incoming updates via an outgoing webhook.",
    url: "https://api.telegram.org/bot/setWebhook",
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        url: %{
          type: :string,
          description: "HTTPS URL to send updates to"
        },
        secret_token: %{
          type: :string,
          description: "A secret token to be sent in a header X-Telegram-Bot-Api-Secret-Token in every webhook request"
        }
      },
      required: ["url"]
    }

  @impl true
  def after_focus(%{"ok" => true, "result" => result, "description" => description}) do
    {:ok, %{result: result, description: description}}
  end

  def after_focus(%{"ok" => true, "result" => result}) do
    {:ok, result}
  end

  def after_focus(%{"ok" => false, "description" => description} = error) do
    {:error, error}
  end

  def after_focus(error) do
    {:error, error}
  end
end
