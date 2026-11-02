defmodule Lux.Lenses.Telegram.Webhooks.SetWebhook do
  @moduledoc """
  A lens for specifying a URL and receiving incoming updates via an outgoing webhook.
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Set Telegram Webhook",
    description: "Specifies a URL and receives incoming updates via an outgoing webhook",
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
          description: "Secret token to be sent in header 'X-Telegram-Bot-Api-Secret-Token'",
          minLength: 1,
          maxLength: 256
        },
        max_connections: %{
          type: :integer,
          description: "Maximum allowed number of simultaneous HTTPS connections (1-100)"
        }
      },
      required: ["url"]
    }

  @impl true
  def before_focus(params) do
    payload = %{"url" => params.url}

    payload =
      if Map.get(params, :secret_token) do
        Map.put(payload, "secret_token", params.secret_token)
      else
        payload
      end

    payload =
      if Map.get(params, :max_connections) do
        Map.put(payload, "max_connections", params.max_connections)
      else
        payload
      end

    {:ok, payload}
  end

  @impl true
  def after_focus(%{"ok" => true, "result" => true, "description" => desc}) do
    {:ok, %{status: :ok, description: desc}}
  end

  def after_focus(%{"ok" => true, "result" => true}) do
    {:ok, %{status: :ok}}
  end

  def after_focus(other), do: {:ok, other}
end
