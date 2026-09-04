defmodule Lux.Lenses.Telegram.Close do
  @moduledoc """
  Lens for closing the bot instance before moving it to another local server.
  """

  use Lux.Telegram.Lens,
    name: "Close",
    description: "Closes the bot instance before moving it from one local server to another",
    url: "https://api.telegram.org/bot/close",
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
