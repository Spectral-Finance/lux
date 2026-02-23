defmodule Lux.Prisms.Discord.GuildEvents.CreateScheduledEvent do
  @moduledoc """
  A prism for creating a scheduled event in a Discord guild.

  Supports external events (with entity_metadata location) and
  channel-based events (voice/stage channels).

  ## Examples
      iex> CreateScheduledEvent.handler(%{
      ...>   guild_id: "123456789012345678",
      ...>   name: "Team Meeting",
      ...>   scheduled_start_time: "2026-03-01T14:00:00Z",
      ...>   entity_type: 3,
      ...>   privacy_level: 2,
      ...>   entity_metadata: %{location: "https://meet.example.com"}
      ...> }, %{name: "Agent"})
      {:ok, %{created: true, event_id: "111111111111111111", name: "Team Meeting"}}
  """

  use Lux.Prism,
    name: "Create Discord Scheduled Event",
    description: "Creates a scheduled event in a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild",
          pattern: "^[0-9]{17,20}$"
        },
        name: %{
          type: :string,
          description: "The name of the event (1-100 characters)",
          minLength: 1,
          maxLength: 100
        },
        scheduled_start_time: %{
          type: :string,
          description: "ISO8601 timestamp for when the event starts"
        },
        scheduled_end_time: %{
          type: :string,
          description: "ISO8601 timestamp for when the event ends (required for external events)"
        },
        entity_type: %{
          type: :integer,
          description: "1: STAGE_INSTANCE, 2: VOICE, 3: EXTERNAL",
          enum: [1, 2, 3]
        },
        privacy_level: %{
          type: :integer,
          description: "2: GUILD_ONLY (only supported value)",
          enum: [2]
        },
        description: %{
          type: :string,
          description: "Description of the event (max 1000 characters)",
          maxLength: 1000
        },
        channel_id: %{
          type: :string,
          description: "Channel ID for STAGE_INSTANCE or VOICE entity types",
          pattern: "^[0-9]{17,20}$"
        },
        entity_metadata: %{
          type: :object,
          description: "Additional event metadata (required for EXTERNAL events with 'location' field)"
        }
      },
      required: ["guild_id", "name", "scheduled_start_time", "entity_type", "privacy_level"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        created: %{type: :boolean, description: "Whether the event was created"},
        event_id: %{type: :string, description: "The ID of the created event"},
        name: %{type: :string, description: "The name of the created event"}
      },
      required: ["created"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_snowflake(params, :guild_id),
         {:ok, name} <- validate_string(params, :name),
         {:ok, start_time} <- validate_string(params, :scheduled_start_time),
         {:ok, entity_type} <- validate_integer(params, :entity_type),
         {:ok, privacy_level} <- validate_integer(params, :privacy_level) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} creating scheduled event '#{name}' in guild #{guild_id}")

      body = %{
        name: name,
        scheduled_start_time: start_time,
        entity_type: entity_type,
        privacy_level: privacy_level
      }
      |> maybe_put(:scheduled_end_time, params)
      |> maybe_put(:description, params)
      |> maybe_put(:channel_id, params)
      |> maybe_put(:entity_metadata, params)

      case Client.request(:post, "/guilds/#{guild_id}/scheduled-events", %{json: body}) do
        {:ok, %{"id" => event_id, "name" => event_name}} ->
          Logger.info("Successfully created event #{event_id} in guild #{guild_id}")
          {:ok, %{created: true, event_id: event_id, name: event_name}}
        {:error, {status, %{"message" => message}}} ->
          Logger.error("Failed to create event in guild #{guild_id}: #{message}")
          {:error, {status, message}}
        {:error, error} ->
          Logger.error("Failed to create event in guild #{guild_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp maybe_put(body, key, params) do
    case Map.fetch(params, key) do
      {:ok, value} when not is_nil(value) -> Map.put(body, key, value)
      _ -> body
    end
  end

  defp validate_snowflake(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_string(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_integer(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_integer(value) -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
