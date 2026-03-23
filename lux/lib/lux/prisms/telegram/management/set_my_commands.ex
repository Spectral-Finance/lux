defmodule Lux.Prisms.Telegram.Management.SetMyCommands do
  @moduledoc """
  A prism for setting the bot's command list via the Telegram Bot API.

  This prism provides an interface to call the setMyCommands endpoint, which
  changes the list of the bot's commands visible in the Telegram interface.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /setMyCommands
  - Requires a list of commands (each with command and description)
  - Optional scope and language_code parameters
  - Returns true on success

  ## Examples

      iex> SetMyCommands.handler(%{
      ...>   commands: [%{command: "start", description: "Start the bot"}]
      ...> }, %{name: "Agent"})
      {:ok, %{success: true}}
  """

  use Lux.Prism,
    name: "Set Telegram Bot Commands",
    description: "Sets the list of the bot's commands via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        commands: %{
          type: :array,
          description: "A list of bot commands to be set",
          items: %{
            type: :object,
            properties: %{
              command: %{
                type: :string,
                description: "Text of the command; 1-32 characters"
              },
              description: %{
                type: :string,
                description: "Description of the command; 1-256 characters"
              }
            },
            required: ["command", "description"]
          }
        },
        scope: %{
          type: :object,
          description: "Scope of users for which the commands are relevant"
        },
        language_code: %{
          type: :string,
          description: "A two-letter ISO 639-1 language code"
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
        }
      },
      required: ["success"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to set bot commands.
  """
  def handler(params, agent) do
    with {:ok, commands} <- validate_commands(params) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} setting bot commands")

      request_body = Map.take(params, [:commands, :scope, :language_code])
      request_opts = %{json: request_body}
      request_opts = maybe_add_plug(request_opts, params[:plug])

      case Client.request(:post, "/setMyCommands", request_opts) do
        {:ok, %{"result" => true}} ->
          Logger.info("Successfully set bot commands")
          {:ok, %{success: true}}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to set commands: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to set commands: #{inspect(error)}"}
      end
    end
  end

  defp validate_commands(%{commands: commands}) when is_list(commands) and length(commands) > 0,
    do: {:ok, commands}
  defp validate_commands(_), do: {:error, "Missing or invalid commands"}

  defp maybe_add_plug(opts, nil), do: opts
  defp maybe_add_plug(opts, plug), do: Map.put(opts, :plug, plug)
end
