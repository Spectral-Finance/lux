defmodule Lux.Prisms.Discord.Channels.EditChannelPermissions do
  @moduledoc """
  A prism for editing channel permission overwrites in Discord.

  Sets permissions for a specific role or member in a channel.

  ## Examples
      iex> EditChannelPermissions.handler(%{
      ...>   channel_id: "123456789",
      ...>   overwrite_id: "987654321",
      ...>   type: 0,
      ...>   allow: "1024",
      ...>   deny: "2048"
      ...> }, %{name: "Agent"})
      {:ok, %{updated: true, channel_id: "123456789", overwrite_id: "987654321"}}
  """

  use Lux.Prism,
    name: "Edit Discord Channel Permissions",
    description: "Edits channel permission overwrites for a role or member",
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
        type: %{
          type: :integer,
          description: "0 for role, 1 for member",
          enum: [0, 1]
        },
        allow: %{
          type: :string,
          description: "Bitwise value of allowed permissions"
        },
        deny: %{
          type: :string,
          description: "Bitwise value of denied permissions"
        }
      },
      required: ["channel_id", "overwrite_id", "type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        updated: %{
          type: :boolean,
          description: "Whether the permissions were successfully updated"
        },
        channel_id: %{
          type: :string,
          description: "The ID of the channel"
        },
        overwrite_id: %{
          type: :string,
          description: "The ID of the role or user"
        }
      },
      required: ["updated"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to edit channel permission overwrites.

  Returns {:ok, %{updated: true, channel_id: id, overwrite_id: id}} on success.
  Returns {:error, reason} on failure.
  """
  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, overwrite_id} <- validate_param(params, :overwrite_id),
         {:ok, type} <- validate_int_param(params, :type) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} editing permissions for #{overwrite_id} in channel #{channel_id}")

      body = %{type: type}
      body = if params[:allow], do: Map.put(body, :allow, params[:allow]), else: body
      body = if params[:deny], do: Map.put(body, :deny, params[:deny]), else: body

      case Client.request(:put, "/channels/#{channel_id}/permissions/#{overwrite_id}", %{json: body}) do
        {:ok, _} ->
          Logger.info("Successfully updated permissions for #{overwrite_id} in channel #{channel_id}")
          {:ok, %{updated: true, channel_id: channel_id, overwrite_id: overwrite_id}}
        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to edit permissions in channel #{channel_id}: #{inspect(error)}")
          {:error, error}
        {:error, error} ->
          Logger.error("Failed to edit permissions in channel #{channel_id}: #{inspect(error)}")
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

  defp validate_int_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_integer(value) -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
