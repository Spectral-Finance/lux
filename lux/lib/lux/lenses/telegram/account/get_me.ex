defmodule Lux.Lenses.Telegram.Account.GetMe do
  @moduledoc """
  A lens for getting basic information about the bot.
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram Bot Info",
    description: "Returns basic information about the bot in form of a User object.",
    url: "https://api.telegram.org/bot/getMe",
    method: :get,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{}
    }

  @impl true
  def after_focus(%{"ok" => true, "result" => user}) do
    {:ok, user}
  end

  def after_focus(%{"ok" => false} = error) do
    {:error, error}
  end
end
