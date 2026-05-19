defmodule Lux.Lenses.Telegram.GetMe do
  @moduledoc """
  A lens for getting basic information about the bot.
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram Bot Info",
    description: "Returns basic information about the bot in the form of a User object",
    url: "https://api.telegram.org/bot:token/getMe",
    method: :get,
    headers: Telegram.headers(),
    auth: Telegram.auth()

  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    {:ok, result}
  end

  def after_focus(error) do
    {:error, error}
  end
end
