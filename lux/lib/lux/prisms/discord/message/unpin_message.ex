defmodule Lux.Prisms.Discord.Messages.UnpinMessage do
  @moduledoc """
  A prism for unpinning messages in a Discord channel.
  """

  use Lux.Prism,
    name: "Unpin Discord Message",
    description: "Unpins a message in a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel containing the message",
          pattern: "^[0-9]{17,20}$"
        },
        message_id: %{
          type: :string,
          description: "The ID of the message to unpin",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["channel_id", "message_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        unpinned: %{
          type: :boolean,
          description: "Whether the message was successfully unpinned"
        },
        message_id: %{
          type: :string,
          description: "The ID of the unpinned message"
        },
        channel_id: %{
          type: :string,
          description: "The ID of the channel containing the message"
        }
      },
      required: ["unpinned"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to unpin a message in a Discord channel.
  """
  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, message_id} <- validate_param(params, :message_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} unpinning message #{message_id} in channel #{channel_id}")

      case Client.request(:delete, "/channels/#{channel_id}/pins/#{message_id}") do
        {:ok, _} ->
          Logger.info("Successfully unpinned message #{message_id} in channel #{channel_id}")
          {:ok, %{unpinned: true, message_id: message_id, channel_id: channel_id}}

        error ->
          Logger.error("Failed to unpin message #{message_id} in channel #{channel_id}: #{inspect(error)}")
          error
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
