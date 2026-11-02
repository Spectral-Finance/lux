defmodule Lux.Prisms.Discord.Messages.DeleteMessage do
  @moduledoc """
  A prism for deleting a message from a Discord channel.
  """

  use Lux.Prism,
    name: "Delete Discord Message",
    description: "Deletes a specific message in a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "Target Discord channel snowflake ID"
        },
        message_id: %{
          type: :string,
          description: "Target Discord message snowflake ID to delete"
        }
      },
      required: ["channel_id", "message_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        deleted: %{type: :boolean},
        channel_id: %{type: :string},
        message_id: %{type: :string}
      },
      required: ["deleted", "channel_id", "message_id"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, message_id} <- validate_param(params, :message_id) do
      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Agent"
      Logger.info("Agent #{agent_name} deleting Discord message #{message_id} in channel #{channel_id}")

      opts = %{}
      opts = if plug = params[:plug], do: Map.put(opts, :plug, plug), else: opts
      opts = if token = params[:token], do: Map.put(opts, :token, token), else: opts

      case Client.request(:delete, "/channels/#{channel_id}/messages/#{message_id}", opts) do
        {:ok, _} ->
          {:ok, %{
            deleted: true,
            message_id: message_id,
            channel_id: channel_id
          }}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, val} when is_binary(val) and val != "" -> {:ok, val}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
