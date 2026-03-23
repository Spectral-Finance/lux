defmodule Lux.Prisms.Telegram.Management.GetMyCommands do
  @moduledoc """
  A prism for getting the bot's command list via the Telegram Bot API.

  This prism provides an interface to call the getMyCommands endpoint, which
  returns the current list of the bot's commands for the given scope and language.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /getMyCommands
  - Optional scope and language_code parameters
  - Returns a list of BotCommand objects

  ## Examples

      iex> GetMyCommands.handler(%{}, %{name: "Agent"})
      {:ok, %{commands: [%{"command" => "start", "description" => "Start the bot"}]}}
  """

  use Lux.Prism,
    name: "Get Telegram Bot Commands",
    description: "Gets the list of the bot's commands via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        scope: %{
          type: :object,
          description: "Scope of users for which the commands are relevant"
        },
        language_code: %{
          type: :string,
          description: "A two-letter ISO 639-1 language code"
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        commands: %{
          type: :array,
          description: "List of bot commands"
        }
      },
      required: ["commands"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to get bot commands.
  """
  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} getting bot commands")

    request_body = Map.take(params, [:scope, :language_code])
    request_opts = %{json: request_body}
    request_opts = maybe_add_plug(request_opts, params[:plug])

    case Client.request(:post, "/getMyCommands", request_opts) do
      {:ok, %{"result" => commands}} ->
        Logger.info("Successfully retrieved bot commands")
        {:ok, %{commands: commands}}

      {:error, {status, description}} when is_binary(description) ->
        {:error, "Failed to get commands: #{description} (HTTP #{status})"}

      {:error, error} ->
        {:error, "Failed to get commands: #{inspect(error)}"}
    end
  end

  defp maybe_add_plug(opts, nil), do: opts
  defp maybe_add_plug(opts, plug), do: Map.put(opts, :plug, plug)
end
