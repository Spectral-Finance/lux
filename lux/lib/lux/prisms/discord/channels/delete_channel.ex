defmodule Lux.Prisms.Discord.Channels.DeleteChannel do
  @moduledoc """
  A prism for deleting channels from a Discord guild.

  This prism provides a simple interface for deleting Discord channels with:
  - Minimal required parameters (channel_id)
  - Direct Discord API error propagation
  - Simple success/failure response structure

  ## Examples
      iex> DeleteChannel.handler(%{
      ...>   channel_id: "123456789"
      ...> }, %{name: "Agent"})
      {:ok, %{
        deleted: true,
        channel_id: "123456789"
      }}
  """

  use Lux.Prism,
    name: "Delete Discord Channel",
    description: "Deletes a channel from a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to delete",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        deleted: %{
          type: :boolean,
          description: "Whether the channel was successfully deleted"
        },
        channel_id: %{
          type: :string,
          description: "The ID of the deleted channel"
        }
      },
      required: ["deleted"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to delete a channel from a Discord guild.

  Returns {:ok, %{deleted: true, channel_id: id}} on success.
  Returns {:error, {status, message}} on failure.
  """
  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} deleting channel #{channel_id}")

      case Client.request(:delete, "/channels/#{channel_id}") do
        {:ok, %{"id" => channel_id}} ->
          Logger.info("Successfully deleted channel #{channel_id}")
          {:ok, %{deleted: true, channel_id: channel_id}}
        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to delete channel #{channel_id}: #{inspect(error)}")
          {:error, error}
        {:error, error} ->
          Logger.error("Failed to delete channel #{channel_id}: #{inspect(error)}")
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
