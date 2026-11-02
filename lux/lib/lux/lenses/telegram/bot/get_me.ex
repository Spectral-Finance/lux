defmodule Lux.Lenses.Telegram.Bot.GetMe do
  @moduledoc """
  A lens for testing bot authentication and retrieving bot user details from Telegram Bot API.
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram Bot Info",
    description: "Returns basic information about the bot in the form of a User object",
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

  def after_focus(other), do: {:ok, other}
end
