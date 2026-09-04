defmodule Lux.Lenses.Telegram.LogOut do
  @moduledoc """
  Lens for logging out from the Cloud Bot API server.
  """

  use Lux.Telegram.Lens,
    name: "LogOut",
    description: "Logs out from the cloud Bot API server before launching the bot locally",
    url: "https://api.telegram.org/bot/logOut",
    method: :post,
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
