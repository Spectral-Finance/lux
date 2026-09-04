defmodule Lux.Lenses.Telegram.GetMe do
  @moduledoc """
  Lens for testing Telegram Bot API authentication token and fetching bot user information.
  """

  use Lux.Telegram.Lens,
    name: "GetMe",
    description: "Returns basic information about the bot in form of a User object",
    url: "https://api.telegram.org/bot/getMe",
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
