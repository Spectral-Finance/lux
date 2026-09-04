defmodule Lux.Lenses.Telegram.GetWebhookInfo do
  @moduledoc """
  Lens for querying current status of a Telegram bot's webhook integration.
  """

  use Lux.Telegram.Lens,
    name: "GetWebhookInfo",
    description: "Use this method to get current webhook status",
    url: "https://api.telegram.org/bot/getWebhookInfo",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        token: %{
          type: :string,
          description: "Telegram Bot API Token (optional if configured globally)"
        }
      }
    }
end
