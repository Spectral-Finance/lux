defmodule Lux.Lenses.Telegram.SetWebhook do
  @moduledoc """
  Lens for configuring an outgoing webhook URL for receiving Telegram updates.
  """

  use Lux.Telegram.Lens,
    name: "SetWebhook",
    description: "Specifies a URL and receives incoming updates via an outgoing webhook",
    url: "https://api.telegram.org/bot/setWebhook",
    method: :post,
    schema: %{
      type: :object,
      properties: %{
        url: %{
          type: :string,
          description: "HTTPS URL to send updates to"
        },
        ip_address: %{
          type: :string,
          description: "Fixed IP address to use to send webhook requests"
        },
        max_connections: %{
          type: :integer,
          description: "Maximum allowed number of simultaneous connections"
        },
        allowed_updates: %{
          type: :array,
          items: %{type: :string},
          description: "List of update types to receive"
        },
        drop_pending_updates: %{
          type: :boolean,
          description: "Pass true to drop all pending updates"
        },
        secret_token: %{
          type: :string,
          description: "Secret token to be sent in X-Telegram-Bot-Api-Secret-Token header"
        }
      },
      required: ["url"]
    }

  def before_focus(params) when is_map(params) do
    case Map.pop(params, :url) do
      {nil, params} -> params
      {webhook_url, params} -> Map.put(params, "url", webhook_url)
    end
  end

  def before_focus(params), do: params
end
