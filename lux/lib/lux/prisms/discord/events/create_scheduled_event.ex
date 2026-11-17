defmodule Lux.Prisms.Discord.Events.CreateScheduledEvent do
  @moduledoc """
  A prism for creating a scheduled event in a Discord guild.

  Supports stage, voice, and external event types.

  ## Examples
      iex> CreateScheduledEvent.handler(%{
      ...>   guild_id: "123456789",
      ...>   name: "Community Meetup",
      ...>   scheduled_start_time: "2024-12-25T18:00:00Z",
      ...>   privacy_level: 2,
      ...>   entity_type: 3,
      ...>   entity_metadata: %{location: "Discord Stage"}
      ...> }, %{name: "Agent"})
      {:ok, %{created: true, event_id: "111111111111111111", name: "Community Meetup",
              guild_id: "123456789"}}
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
          description: "Name of the event (1-100 characters)",
          minLength: 1,
          maxLength: 100
        },
        description: %{
          type: :string,
          description: "Description of the event (1-1000 characters)",
          maxLength: 1000
        },
        scheduled_start_time: %{
          type: :string,
          description: "ISO8601 timestamp for when the event starts"
        },
        scheduled_end_time: %{
          type: :string,
          description: "ISO8601 timestamp for when the event ends (required for external events)"
        },
        privacy_level: %{
          type: :integer,
          description: "Privacy level (2 = GUILD_ONLY)",
          enum: [2]
        },
        entity_type: %{
          type: :integer,
          description: "Type of event (1=STAGE_INSTANCE, 2=VOICE, 3=EXTERNAL)",
          enum: [1, 2, 3]
        },
        channel_id: %{
          type: :string,
          description: "Channel ID for stage/voice events",
          pattern: "^[0-9]{17,20}$"
        },
        entity_metadata: %{
          type: :object,
          description: "Metadata for external events (contains location)",
          properties: %{
            location: %{type: :string, description: "Location of external event"}
          }
        }
      },
      required: ["guild_id", "name", "scheduled_start_time", "privacy_level", "entity_type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        created: %{
          type: :boolean,
          description: "Whether the event was successfully created"
        },
        event_id: %{
          type: :string,
          description: "The ID of the created event"
        },
        name: %{
          type: :string,
          description: "The name of the event"
        },
        guild_id: %{
          type: :string,
          description: "The ID of the guild"
        }
      },
      required: ["created"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @optional_fields ~w(description scheduled_end_time channel_id entity_metadata)a

  @doc """
  Handles the request to create a scheduled event.

  Returns {:ok, %{created: true, event_id: id, name: name, guild_id: id}} on success.
  Returns {:error, reason} on failure.
  """
  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, name} <- validate_param(params, :name),
         {:ok, start_time} <- validate_param(params, :scheduled_start_time),
         {:ok, privacy_level} <- validate_int_param(params, :privacy_level),
         {:ok, entity_type} <- validate_int_param(params, :entity_type) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} creating scheduled event '#{name}' in guild #{guild_id}")

      body =
        %{
          name: name,
          scheduled_start_time: start_time,
          privacy_level: privacy_level,
          entity_type: entity_type
        }
        |> merge_optional_fields(params)

      case Client.request(:post, "/guilds/#{guild_id}/scheduled-events", %{json: body}) do
        {:ok, %{"id" => event_id, "name" => event_name}} ->
          Logger.info("Successfully created event #{event_id} in guild #{guild_id}")
          {:ok, %{created: true, event_id: event_id, name: event_name, guild_id: guild_id}}
        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to create event in guild #{guild_id}: #{inspect(error)}")
          {:error, error}
        {:error, error} ->
          Logger.error("Failed to create event in guild #{guild_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp merge_optional_fields(body, params) do
    Enum.reduce(@optional_fields, body, fn field, acc ->
      case Map.get(params, field) do
        nil -> acc
        value -> Map.put(acc, field, value)
      end
    end)
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
