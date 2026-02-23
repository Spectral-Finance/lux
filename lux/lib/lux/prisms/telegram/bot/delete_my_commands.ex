defmodule Lux.Prisms.Telegram.Bot.DeleteMyCommands do
  @moduledoc """
  A prism for deleting the list of commands registered for the Telegram bot.

  Deletes the list of the bot's commands for the given scope and user language.
  After deletion, higher level commands will be shown to affected users.

  ## Examples

      iex> DeleteMyCommands.handler(%{}, %{name: "Agent"})
      {:ok, %{success: true, description: "Commands deleted for default scope"}}

      iex> DeleteMyCommands.handler(%{
      ...>   scope: %{type: "all_private_chats"},
      ...>   language_code: "en"
      ...> }, %{name: "Agent"})
      {:ok, %{success: true, description: "Commands deleted for scope all_private_chats"}}
  """

  use Lux.Prism,
    name: "Delete Telegram Bot Commands",
    description: "Deletes the registered commands for the Telegram bot for a given scope",
    input_schema: %{
      type: :object,
      properties: %{
        scope: %{
          type: :object,
          description: "An object describing the scope of users for which the commands are deleted. Defaults to BotCommandScopeDefault."
        },
        language_code: %{
          type: :string,
          description: "A two-letter ISO 639-1 language code. If empty, commands for all languages in scope are deleted."
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether the commands were successfully deleted"
        },
        description: %{
          type: :string,
          description: "Human-readable description of the result"
        }
      },
      required: ["success"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} deleting Telegram bot commands")

    scope = params[:scope] || params["scope"]
    language_code = params[:language_code] || params["language_code"]

    body =
      %{}
      |> maybe_put(:scope, scope)
      |> maybe_put(:language_code, language_code)

    request_opts = %{json: body}
    request_opts = if plug = params[:plug], do: Map.put(request_opts, :plug, plug), else: request_opts

    case Client.request(:post, "/deleteMyCommands", request_opts) do
      {:ok, %{"ok" => true, "result" => true}} ->
        scope_desc = if scope, do: "scope #{scope["type"] || "custom"}", else: "default scope"
        Logger.info("Commands deleted for #{scope_desc}")
        {:ok, %{success: true, description: "Commands deleted for #{scope_desc}"}}

      {:ok, %{"ok" => false, "description" => description}} ->
        {:error, "Failed to delete commands: #{description}"}

      {:error, {status, description}} when is_binary(description) ->
        {:error, "Failed to delete commands: #{description} (HTTP #{status})"}

      {:error, error} ->
        {:error, "Failed to delete commands: #{inspect(error)}"}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
