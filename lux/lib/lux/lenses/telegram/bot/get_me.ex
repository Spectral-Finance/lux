defmodule Lux.Lenses.Telegram.Bot.GetMe do
  @moduledoc """
  A lens for testing Telegram Bot API authentication using the getMe method.
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Telegram Bot GetMe",
    description: "Returns basic information about the bot in form of a User object.",
    url: "https://api.telegram.org/bot<token>/getMe",
    method: :get,
    headers: Telegram.headers(),
    auth: Telegram.auth()

  @doc """
  Transforms the Telegram API response.
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    {:ok, result}
  end

  def after_focus(%{"ok" => false, "description" => description}) do
    {:error, description}
  end
  
  def after_focus(other), do: {:error, other}
end
