defmodule Lux.Prisms.Discord.Guilds.CreateScheduledEvent do
  @moduledoc """
  A prism for creating scheduled events in a Discord server.
  Supports various event types including voice channel events, stage events, and external events.

  ## Examples
      iex> CreateScheduledEvent.handler(%{
      ...>   guild_id: "123456789012345678",
      ...>   name: "Community Game Night",
      ...>   description: "Join us for some fun games!",
      ...>   scheduled_start_time: "2024-04-01T18:00:00Z",
      ...>   scheduled_end_time: "2024-04-01T20:00:00Z",
      ...>   entity_type: :voice,
      ...>   channel_id: "987654321098765432",
      ...>   privacy_level: :guild_only
      ...> }, %{name: "Agent"})
      {:ok, %{
        created: true,
        event_id: "111222333444555666",
        name: "Community Game Night"
      }}
  """

  use Lux.Prism,
    name: "Create Scheduled Event",
    description: "Creates a scheduled event in a Discord server",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to create the event in",
          pattern: "^[0-9]{17,20}$"
        },
        name: %{
          type: :string,
          description: "The name of the event",
          minLength: 1,
          maxLength: 100
        },
        description: %{
          type: :string,
          description: "The description of the event",
          maxLength: 1000
        },
        scheduled_start_time: %{
          type: :string,
          description: "The time the event will start (ISO8601 timestamp)",
          pattern: "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"
        },
        scheduled_end_time: %{
          type: :string,
          description: "The time the event will end (ISO8601 timestamp)",
          pattern: "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"
        },
        entity_type: %{
          type: :string,
          description: "The type of event",
          enum: ["stage_instance", "voice", "external"]
        },
        channel_id: %{
          type: :string,
          description: "The channel ID for stage/voice events (not required for external)",
          pattern: "^[0-9]{17,20}$"
        },
        entity_metadata: %{
          type: :object,
          description: "Additional metadata for external events",
          properties: %{
            location: %{
              type: :string,
              description: "Location of the external event",
              maxLength: 100
            }
          }
        },
        privacy_level: %{
          type: :string,
          description: "The privacy level of the event",
          enum: ["guild_only"],
          default: "guild_only"
        },
        image: %{
          type: :string,
          description: "Base64 encoded image for the scheduled event (PNG, JPEG, or GIF)",
          pattern: "^data:image\\/(png|jpeg|gif);base64,[A-Za-z0-9+/=]+$"
        }
      },
      required: [:guild_id, :name, :scheduled_start_time, :entity_type]
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
          description: "The name of the created event"
        }
      },
      required: [:created, :event_id, :name]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the creation of a scheduled event in a Discord server.

  Returns {:ok, %{created: true, event_id: id, name: name}} on success.
  Returns {:error, reason} on failure.
  """
  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, name} <- validate_param(params, :name),
         {:ok, start_time} <- validate_param(params, :scheduled_start_time),
         {:ok, entity_type} <- validate_enum_param(params, :entity_type, ["stage_instance", "voice", "external"]),
         :ok <- validate_channel_id(params, entity_type),
         :ok <- validate_entity_metadata(params, entity_type),
         {:ok, request_data} <- build_request_data(%{params | scheduled_start_time: start_time}),
         {:ok, response} <- make_api_request(guild_id, request_data) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} creating scheduled event '#{name}' in guild #{guild_id}")

      event_id = response["id"]
      Logger.info("Successfully created scheduled event '#{name}' (#{event_id}) in guild #{guild_id}")
      {:ok, %{
        created: true,
        event_id: event_id,
        name: name
      }}
    end
  end

  defp validate_param(params, key) when is_atom(key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_enum_param(params, key, valid_values) when is_atom(key) do
    case Map.fetch(params, key) do
      {:ok, value} ->
        if Enum.member?(valid_values, value) do
          {:ok, value}
        else
          {:error, "Invalid #{key}"}
        end
      _ -> {:error, "Invalid #{key}"}
    end
  end

  defp validate_channel_id(params, entity_type) when entity_type in ["stage_instance", "voice"] do
    case Map.fetch(params, :channel_id) do
      {:ok, channel_id} when is_binary(channel_id) and channel_id != "" -> :ok
      _ -> {:error, "Channel ID is required for stage/voice events"}
    end
  end
  defp validate_channel_id(_params, "external"), do: :ok

  defp validate_entity_metadata(params, "external") do
    case get_in(params, [:entity_metadata, :location]) do
      location when is_binary(location) and location != "" -> :ok
      _ -> {:error, "Location is required for external events"}
    end
  end
  defp validate_entity_metadata(_params, _type), do: :ok

  defp build_request_data(params) do
    data = %{
      "name" => params.name,
      "scheduled_start_time" => params.scheduled_start_time,
      "entity_type" => entity_type_to_int(params.entity_type),
      "privacy_level" => 2  # GUILD_ONLY
    }
    |> maybe_add_description(params)
    |> maybe_add_end_time(params)
    |> maybe_add_channel_id(params)
    |> maybe_add_entity_metadata(params)
    |> maybe_add_image(params)

    {:ok, data}
  end

  defp entity_type_to_int("stage_instance"), do: 1
  defp entity_type_to_int("voice"), do: 2
  defp entity_type_to_int("external"), do: 3

  defp maybe_add_description(data, %{description: description}) when is_binary(description) and description != "" do
    Map.put(data, "description", description)
  end
  defp maybe_add_description(data, _), do: data

  defp maybe_add_end_time(data, %{scheduled_end_time: end_time}) when is_binary(end_time) and end_time != "" do
    Map.put(data, "scheduled_end_time", end_time)
  end
  defp maybe_add_end_time(data, _), do: data

  defp maybe_add_channel_id(data, %{channel_id: channel_id}) when is_binary(channel_id) and channel_id != "" do
    Map.put(data, "channel_id", channel_id)
  end
  defp maybe_add_channel_id(data, _), do: data

  defp maybe_add_entity_metadata(data, %{entity_metadata: %{location: location}}) when is_binary(location) and location != "" do
    Map.put(data, "entity_metadata", %{"location" => location})
  end
  defp maybe_add_entity_metadata(data, _), do: data

  defp maybe_add_image(data, %{image: image}) when is_binary(image) and image != "" do
    Map.put(data, "image", image)
  end
  defp maybe_add_image(data, _), do: data

  defp make_api_request(guild_id, request_data) do
    path = "/guilds/#{guild_id}/scheduled-events"
    plug = Map.get(request_data, :plug)
    opts = %{
      json: request_data,
      plug: plug
    }
    |> Map.reject(fn {_k, v} -> is_nil(v) end)

    case Client.request(:post, path, opts) do
      {:ok, response} -> {:ok, response}
      {:error, {_status, %{"code" => code, "message" => message}}} -> {:error, %{"code" => code, "message" => message}}
      {:error, {_status, message}} when is_binary(message) -> {:error, %{"code" => 50_013, "message" => message}}
      {:error, error} -> {:error, error}
    end
  end
end
