defmodule Lux.Lenses.Telegram.GetMyCommands do
  @moduledoc """
  A lens for getting the current list of the bot's commands.
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram Bot Commands",
    description: "Returns the current list of the bot's commands",
    url: "https://api.telegram.org/bot:token/getMyCommands",
    method: :get,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        scope: %{type: :object, description: "A JSON-serialized object, describing scope of users for which the commands are relevant"},
        language_code: %{type: :string, description: "A two-letter ISO 639-1 language code"}
      }
    }

  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    {:ok, result}
  end

  def after_focus(error) do
    {:error, error}
  end
end
