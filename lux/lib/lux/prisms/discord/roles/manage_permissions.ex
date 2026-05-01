defmodule Lux.Prisms.Discord.Roles.ManagePermissions do
  @moduledoc """
  A prism for managing channel-level permission overrides for roles in Discord.

  ## Examples

      iex> ManagePermissions.handler(%{
      ...>   channel_id: "123456789",
      ...>   overwrite_id: "333333333333333333",
      ...>   allow: 1024,
      ...>   deny: 0,
      ...>   type: "role"
      ...> }, %{name: "Agent"})
      {:ok, %{updated: true, channel_id: "123456789", overwrite_id: "333333333333333333"}}
  """

  use Lux.Prism,
    name: "Manage Discord Channel Permissions",
    description: "Manages permission overrides for a role or user in a Discord channel",
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
          description: "The ID of the role or user to set permissions for",
          pattern: "^[0-9]{17,20}$"
        },
        allow: %{
          type: :integer,
          description: "Permission bitset for allowed permissions",
          minimum: 0
        },
        deny: %{
          type: :integer,
          description: "Permission bitset for denied permissions",
          minimum: 0
        },
        type: %{
          type: :string,
          description: "Type of the overwrite target",
          enum: ["role", "member"],
          default: "role"
        },
        reason: %{
          type: :string,
          description: "Optional audit log reason",
          maxLength: 500
        }
      },
      required: ["channel_id", "overwrite_id", "allow", "deny"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        updated: %{type: :boolean, description: "Whether permissions were successfully updated"},
        channel_id: %{type: :string, description: "The channel ID"},
        overwrite_id: %{type: :string, description: "The role/user ID permissions were set for"}
      },
      required: ["updated"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, overwrite_id} <- validate_param(params, :overwrite_id),
         {:ok, allow} <- validate_param_int(params, :allow),
         {:ok, deny} <- validate_param_int(params, :deny),
         {:ok, type} <- validate_optional_param(params, :type, "role") do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} managing permissions for #{overwrite_id} in channel #{channel_id}")

      body = %{allow: allow, deny: deny, type: type}

      case Client.request(:put, "/channels/#{channel_id}/permissions/#{overwrite_id}", %{json: body}) do
        {:ok, _} ->
          {:ok, %{updated: true, channel_id: channel_id, overwrite_id: overwrite_id}}
        {:error, %{"status" => 204}} ->
          {:ok, %{updated: true, channel_id: channel_id, overwrite_id: overwrite_id}}
        error ->
          Logger.error("Failed to manage permissions: #{inspect(error)}")
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

  defp validate_param_int(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_integer(value) -> {:ok, value}
      {:ok, value} when is_binary(value) ->
        case Integer.parse(value) do
          {int_val, _} -> {:ok, int_val}
          :error -> {:error, "Invalid integer for #{key}"}
        end
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_optional_param(params, key, default \\ nil) do
    case Map.get(params, key, default) do
      nil -> {:ok, nil}
      value -> {:ok, value}
    end
  end
end
