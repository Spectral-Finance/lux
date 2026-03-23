defmodule Lux.Prisms.Telegram.Management.DeleteMyCommands do
  @moduledoc """
  A prism for deleting the bot's command list via the Telegram Bot API.

  This prism provides an interface to call the deleteMyCommands endpoint, which
  deletes the list of the bot's commands for the given scope and language.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /deleteMyCommands
  - Optional scope and language_code parameters
  - Returns true on success

  ## Examples

      iex> DeleteMyCommands.handler(%{}, %{name: "Agent"})
      {:ok, %{success: true}}
  """

  use Lux.Prism,
    name: "Delete Telegram Bot Commands",
    description: "Deletes the list of the bot's commands via the Telegram Bot API",
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
        success: %{
          type: :boolean,
          description: "Whether the commands were successfully deleted"
        }
      },
      required: ["success"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to delete bot commands.
  """
  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} deleting bot commands")

    request_body = Map.take(params, [:scope, :language_code])
    request_opts = %{json: request_body}
    request_opts = maybe_add_plug(request_opts, params[:plug])

    case Client.request(:post, "/deleteMyCommands", request_opts) do
      {:ok, %{"result" => true}} ->
        Logger.info("Successfully deleted bot commands")
        {:ok, %{success: true}}

      {:error, {status, %{"description" => description}}} ->
        {:error, "Failed to delete commands: #{description} (HTTP #{status})"}

      {:error, {status, description}} when is_binary(description) ->
        {:error, "Failed to delete commands: #{description} (HTTP #{status})"}

      {:error, error} ->
        {:error, "Failed to delete commands: #{inspect(error)}"}
    end
  end

  defp maybe_add_plug(opts, nil), do: opts
  defp maybe_add_plug(opts, plug), do: Map.put(opts, :plug, plug)
end
