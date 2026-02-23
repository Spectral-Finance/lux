defmodule Lux.Prisms.Telegram.Bot.SetMyCommands do
  @moduledoc """
  A prism for setting the list of commands for the Telegram bot.

  Commands are shown to users when they type "/" in the chat.
  You can set different commands for different scopes and languages.

  ## Examples

      iex> SetMyCommands.handler(%{
      ...>   commands: [
      ...>     %{command: "start", description: "Start the bot"},
      ...>     %{command: "help", description: "Show help"}
      ...>   ]
      ...> }, %{name: "Agent"})
      {:ok, %{success: true, command_count: 2}}

      iex> SetMyCommands.handler(%{
      ...>   commands: [
      ...>     %{command: "start", description: "Iniciar el bot"}
      ...>   ],
      ...>   language_code: "es"
      ...> }, %{name: "Agent"})
      {:ok, %{success: true, command_count: 1}}
  """

  use Lux.Prism,
    name: "Set Telegram Bot Commands",
    description: "Sets the list of commands shown to users in the Telegram bot menu",
    input_schema: %{
      type: :object,
      properties: %{
        commands: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              command: %{
                type: :string,
                description: "Text of the command (1-32 chars, lowercase, no spaces)"
              },
              description: %{
                type: :string,
                description: "Description of the command (3-256 chars)"
              }
            },
            required: ["command", "description"]
          },
          description: "List of bot commands to set (maximum 100)"
        },
        scope: %{
          type: :object,
          description: "An object describing the scope of users for which the commands are relevant"
        },
        language_code: %{
          type: :string,
          description: "A two-letter ISO 639-1 language code. Empty string applies to all users in scope."
        }
      },
      required: ["commands"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether the commands were successfully set"
        },
        command_count: %{
          type: :integer,
          description: "Number of commands that were set"
        }
      },
      required: ["success"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, commands} <- validate_commands(params) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} setting #{length(commands)} Telegram bot commands")

      body =
        %{commands: commands}
        |> maybe_put(:scope, params[:scope] || params["scope"])
        |> maybe_put(:language_code, params[:language_code] || params["language_code"])

      request_opts = %{json: body}
      request_opts = if plug = params[:plug], do: Map.put(request_opts, :plug, plug), else: request_opts

      case Client.request(:post, "/setMyCommands", request_opts) do
        {:ok, %{"ok" => true, "result" => true}} ->
          Logger.info("Successfully set #{length(commands)} commands")
          {:ok, %{success: true, command_count: length(commands)}}

        {:ok, %{"ok" => false, "description" => description}} ->
          {:error, "Failed to set commands: #{description}"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to set commands: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to set commands: #{inspect(error)}"}
      end
    end
  end

  defp validate_commands(params) do
    case params[:commands] || params["commands"] do
      nil ->
        {:error, "commands is required"}

      [] ->
        {:error, "commands cannot be empty — use delete_my_commands to remove all commands"}

      commands when is_list(commands) ->
        if length(commands) > 100 do
          {:error, "Cannot set more than 100 commands"}
        else
          validated = Enum.map(commands, fn cmd ->
            %{
              "command" => cmd[:command] || cmd["command"],
              "description" => cmd[:description] || cmd["description"]
            }
          end)
          {:ok, validated}
        end

      _ ->
        {:error, "commands must be a list"}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
