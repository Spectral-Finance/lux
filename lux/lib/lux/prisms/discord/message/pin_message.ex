defmodule Lux.Prisms.Discord.Messages.PinMessage do
  @moduledoc """
  A prism for pinning messages in a Discord channel.

  This prism provides a simple interface for pinning Discord messages with:
  - Minimal required parameters (channel_id, message_id)
  - Direct Discord API error propagation
  - Simple success/failure response structure

  ## Examples
      iex> PinMessage.handler(%{
      ...>   channel_id: "123456789",
      ...>   message_id: "987654321"
      ...> }, %{name: "Agent"})
      {:ok, %{pinned: true}}
  """

  use Lux.Prism,
    name: "Pin Discord Message",
    description: "Pins a message in a Discord channel",
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
          description: "The ID of the message to pin",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["channel_id", "message_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        pinned: %{
          type: :boolean,
          description: "Whether the message was successfully pinned"
        }
      },
      required: ["pinned"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to pin a message in a Discord channel.

  Returns {:ok, %{pinned: true}} on success.
  Returns {:error, {status, message}} on failure.
  """
  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, message_id} <- validate_param(params, :message_id) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} pinning message #{message_id} in channel #{channel_id}")

      case Client.request(:put, "/channels/#{channel_id}/pins/#{message_id}") do
        {:ok, _} ->
          Logger.info("Successfully pinned message #{message_id} in channel #{channel_id}")
          {:ok, %{pinned: true}}
        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to pin message #{message_id} in channel #{channel_id}: #{inspect(error)}")
          {:error, error}
        {:error, error} ->
          Logger.error("Failed to pin message #{message_id} in channel #{channel_id}: #{inspect(error)}")
          {:error, error}
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
