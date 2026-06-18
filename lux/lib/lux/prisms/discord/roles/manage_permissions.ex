defmodule Lux.Prisms.Discord.Roles.ManagePermissions do
  @moduledoc """
  A prism for managing channel-specific permissions for roles.

  Supports:
  - Setting permission overwrites for a role in a channel
  - Clearing permission overwrites for a role in a channel

  Uses Discord's channel permission overwrite endpoint with
  bitwise permission values for allow/deny.

  ## Examples
      iex> ManagePermissions.handler(%{
      ...>   channel_id: "123456789",
      ...>   role_id: "987654321",
      ...>   action: "set",
      ...>   allow: "1024",
      ...>   deny: "2048"
      ...> }, %{name: "Agent"})
      {:ok, %{
        action: "set",
        success: true,
        role_id: "987654321",
        channel_id: "123456789"
      }}

      iex> ManagePermissions.handler(%{
      ...>   channel_id: "123456789",
      ...>   role_id: "987654321",
      ...>   action: "clear"
      ...> }, %{name: "Agent"})
      {:ok, %{
        action: "clear",
        success: true,
        role_id: "987654321",
        channel_id: "123456789"
      }}
  """

  use Lux.Prism,
    name: "Manage Discord Role Permissions",
    description: "Manages channel permission overwrites for a role",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to manage permissions in",
          pattern: "^[0-9]{17,20}$"
        },
        role_id: %{
          type: :string,
          description: "The ID of the role to manage permissions for",
          pattern: "^[0-9]{17,20}$"
        },
        action: %{
          type: :string,
          description: "Action: set or clear permission overwrites",
          enum: ["set", "clear"]
        },
        allow: %{
          type: :string,
          description: "Permission bitwise value to allow (string representation of integer)"
        },
        deny: %{
          type: :string,
          description: "Permission bitwise value to deny (string representation of integer)"
        }
      },
      required: ["channel_id", "role_id", "action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "The action that was performed"
        },
        success: %{
          type: :boolean,
          description: "Whether the action succeeded"
        },
        role_id: %{
          type: :string,
          description: "The ID of the role"
        },
        channel_id: %{
          type: :string,
          description: "The ID of the channel"
        }
      },
      required: ["action", "success"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, role_id} <- validate_param(params, :role_id),
         {:ok, action} <- validate_param(params, :action) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} performing permission action '#{action}' for role #{role_id} in channel #{channel_id}")

      case action do
        "set" ->
          allow = Map.get(params, :allow, "0")
          deny = Map.get(params, :deny, "0")

          body = %{
            type: 0,
            allow: allow,
            deny: deny
          }

          case Client.request(:put, "/channels/#{channel_id}/permissions/#{role_id}", %{json: body}) do
            {:ok, _} ->
              Logger.info("Successfully set permissions for role #{role_id} in channel #{channel_id}")
              {:ok, %{action: "set", success: true, role_id: role_id, channel_id: channel_id}}

            {:error, {status, %{"message" => message}}} ->
              {:error, {status, message}}

            {:error, error} ->
              {:error, error}
          end

        "clear" ->
          case Client.request(:delete, "/channels/#{channel_id}/permissions/#{role_id}") do
            {:ok, _} ->
              Logger.info("Successfully cleared permissions for role #{role_id} in channel #{channel_id}")
              {:ok, %{action: "clear", success: true, role_id: role_id, channel_id: channel_id}}

            {:error, {status, %{"message" => message}}} ->
              {:error, {status, message}}

            {:error, error} ->
              {:error, error}
          end
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
