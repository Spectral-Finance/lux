defmodule Lux.Prisms.Discord.Channels.UpdateChannelPermissions do
  @moduledoc """
  A prism for editing permission overwrites for a channel.

  Creates or updates a permission overwrite for a role or member in a channel.
  Permissions are expressed as bitfield strings (e.g., "0" for no permissions,
  "8" for administrator).

  ## Examples
      iex> UpdateChannelPermissions.handler(%{
      ...>   channel_id: "123456789012345678",
      ...>   overwrite_id: "987654321098765432",
      ...>   type: 0,
      ...>   allow: "2048",
      ...>   deny: "0"
      ...> }, %{name: "Agent"})
      {:ok, %{updated: true, channel_id: "123456789012345678", overwrite_id: "987654321098765432"}}
  """

  use Lux.Prism,
    name: "Update Discord Channel Permissions",
    description: "Creates or updates a permission overwrite for a role or member in a channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel",
          pattern: "^[0-9]{17,20}$"
        },
        overwrite_id: %{
          type: :string,
          description: "The ID of the role or user to apply the overwrite to",
          pattern: "^[0-9]{17,20}$"
        },
        type: %{
          type: :integer,
          description: "0 for role, 1 for member",
          enum: [0, 1]
        },
        allow: %{
          type: :string,
          description: "Bitfield string of allowed permissions"
        },
        deny: %{
          type: :string,
          description: "Bitfield string of denied permissions"
        }
      },
      required: ["channel_id", "overwrite_id", "type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        updated: %{type: :boolean, description: "Whether the overwrite was successfully applied"},
        channel_id: %{type: :string, description: "The ID of the channel"},
        overwrite_id: %{type: :string, description: "The ID of the overwrite target"}
      },
      required: ["updated"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, channel_id} <- validate_snowflake(params, :channel_id),
         {:ok, overwrite_id} <- validate_snowflake(params, :overwrite_id),
         {:ok, type} <- validate_type(params) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} updating permissions for #{overwrite_id} in channel #{channel_id}")

      body = %{
        type: type,
        allow: Map.get(params, :allow, "0"),
        deny: Map.get(params, :deny, "0")
      }

      case Client.request(:put, "/channels/#{channel_id}/permissions/#{overwrite_id}", %{json: body}) do
        {:ok, _} ->
          Logger.info("Successfully updated permissions in channel #{channel_id}")
          {:ok, %{updated: true, channel_id: channel_id, overwrite_id: overwrite_id}}
        {:error, {status, %{"message" => message}}} ->
          Logger.error("Failed to update permissions in channel #{channel_id}: #{message}")
          {:error, {status, message}}
        {:error, error} ->
          Logger.error("Failed to update permissions in channel #{channel_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_snowflake(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_type(params) do
    case Map.fetch(params, :type) do
      {:ok, type} when type in [0, 1] -> {:ok, type}
      _ -> {:error, "Missing or invalid type (must be 0 for role or 1 for member)"}
    end
  end
end
