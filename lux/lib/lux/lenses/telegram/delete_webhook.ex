defmodule Lux.Lenses.Telegram.DeleteWebhook do
  @moduledoc """
  Lens for removing webhook integration from a Telegram bot.
  """

  use Lux.Telegram.Lens,
    name: "DeleteWebhook",
    description: "Removes webhook integration if you decide to switch back to getUpdates",
    url: "https://api.telegram.org/bot/deleteWebhook",
    method: :post,
    schema: %{
      type: :object,
      properties: %{
        drop_pending_updates: %{
          type: :boolean,
          description: "Pass true to drop all pending updates"
        }
      }
    }
end
