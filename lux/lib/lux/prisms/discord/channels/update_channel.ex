defmodule Lux.Prisms.Discord.Channels.UpdateChannel do
  @moduledoc """
  A prism for updating a Discord channel's settings.

  Supports updating name, topic, position, slowmode, NSFW flag, and
  archiving/unarchiving threads via the `archived` field.

  ## Examples
      iex> UpdateChannel.handler(%{
      ...>   channel_id: "123456789012345678",
      ...>   name: "new-name",
      ...>   topic: "Updated channel topic"
      ...> }, %{name: "Agent"})
      {:ok, %{updated: true, channel_id: "123456789012345678"}}

      iex> UpdateChannel.handler(%{
      ...>   channel_id: "123456789012345678",
      ...>   archived: true
      ...> }, %{name: "Agent"})
      {:ok, %{updated: true, channel_id: "123456789012345678"}}
  """

  use Lux.Prism,
    name: "Update Discord Channel",
    description: "Updates a Discord channel's settings (name, topic, slowmode, archive status, etc.)",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to update",
          pattern: "^[0-9]{17,20}$"
        },
        name: %{
          type: :string,
          description: "New channel name (1-100 characters)",
          minLength: 1,
          maxLength: 100
        },
        topic: %{
          type: :string,
          description: "New channel topic (0-1024 characters)",
          maxLength: 1024
        },
        position: %{
          type: :integer,
          description: "Position of the channel in the channel list"
        },
        rate_limit_per_user: %{
          type: :integer,
          description: "Slowmode delay in seconds (0-21600)",
          minimum: 0,
          maximum: 21600
        },
        nsfw: %{
          type: :boolean,
          description: "Whether the channel is NSFW"
        },
        archived: %{
          type: :boolean,
          description: "For threads: whether the thread is archived"
        }
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        updated: %{type: :boolean, description: "Whether the channel was successfully updated"},
        channel_id: %{type: :string, description: "The ID of the updated channel"}
      },
      required: ["updated"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @updatable_fields [:name, :topic, :position, :rate_limit_per_user, :nsfw, :archived]

  def handler(params, agent) do
    with {:ok, channel_id} <- validate_snowflake(params, :channel_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} updating channel #{channel_id}")

      body = Map.take(params, @updatable_fields)

      if map_size(body) == 0 do
        {:error, "No updatable fields provided"}
      else
        case Client.request(:patch, "/channels/#{channel_id}", %{json: body}) do
          {:ok, _} ->
            Logger.info("Successfully updated channel #{channel_id}")
            {:ok, %{updated: true, channel_id: channel_id}}
          {:error, {status, %{"message" => message}}} ->
            Logger.error("Failed to update channel #{channel_id}: #{message}")
            {:error, {status, message}}
          {:error, error} ->
            Logger.error("Failed to update channel #{channel_id}: #{inspect(error)}")
            {:error, error}
        end
      end
    end
  end

  defp validate_snowflake(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
