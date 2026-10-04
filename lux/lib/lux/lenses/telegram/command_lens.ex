defmodule Lux.Lenses.Telegram.CommandLens do
  @moduledoc """
  Lens for querying registered Telegram Bot commands via `/getMyCommands`.
  """

  use Lux.Lens,
    name: "Telegram Command Lens",
    description: "Queries and inspects the list of bot commands configured in Telegram.",
    url: "https://api.telegram.org/bot/getMyCommands",
    method: :post,
    headers: [{"Content-Type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Lux.Integrations.Telegram.add_auth_header/1
    },
    schema: %{
      type: :object,
      properties: %{
        scope: %{
          type: :object,
          description: "A JSON-serialized object describing scope of users for which the commands are relevant."
        },
        language_code: %{
          type: :string,
          description: "A two-letter ISO 639-1 language code or empty string."
        }
      }
    }

  @impl true
  def after_focus(%{"ok" => true, "result" => commands}) when is_list(commands) do
    {:ok, %{commands: commands, count: length(commands)}}
  end

  def after_focus(%{"ok" => false, "description" => desc}) do
    {:error, "Telegram API error: #{desc}"}
  end

  def after_focus(other), do: {:ok, other}
end
