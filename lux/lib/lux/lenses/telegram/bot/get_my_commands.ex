defmodule Lux.Lenses.Telegram.Bot.GetMyCommands do
  @moduledoc """
  A lens for retrieving the list of commands registered for the Telegram bot.

  Returns the current list of bot commands for the given scope and language.

  ## Examples

      iex> GetMyCommands.focus(%{}, %{})
      {:ok, [
        %{command: "start", description: "Start the bot"},
        %{command: "help", description: "Show help information"},
        %{command: "settings", description: "Open settings"}
      ]}

      iex> GetMyCommands.focus(%{scope: %{type: "all_private_chats"}}, %{})
      {:ok, []}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram Bot Commands",
    description: "Retrieves the list of commands registered for the Telegram bot",
    url: "https://api.telegram.org/bot/getMyCommands",
    method: :get,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        scope: %{
          type: :object,
          description: "An object describing the scope of users for which the commands are relevant. Defaults to BotCommandScopeDefault."
        },
        language_code: %{
          type: :string,
          description: "A two-letter ISO 639-1 language code. If empty, commands will be applied to all users from the given scope."
        }
      }
    }

  @impl true
  def before_focus(params) do
    query =
      params
      |> Map.take(["scope", "language_code", :scope, :language_code])
      |> Enum.reduce(%{}, fn {k, v}, acc ->
        Map.put(acc, to_string(k), v)
      end)

    {:ok, query}
  end

  @impl true
  def after_focus(%{"ok" => true, "result" => commands}) when is_list(commands) do
    {:ok, Enum.map(commands, fn cmd ->
      %{
        command: cmd["command"],
        description: cmd["description"]
      }
    end)}
  end

  def after_focus(%{"ok" => false, "description" => description}) do
    {:error, description}
  end

  def after_focus(response) do
    {:error, response}
  end
end
