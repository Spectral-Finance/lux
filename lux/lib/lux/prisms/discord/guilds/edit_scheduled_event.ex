defmodule Lux.Prisms.Discord.Guilds.EditScheduledEvent do
  @moduledoc """
  A prism for editing scheduled events in a Discord guild.

  This prism allows you to modify existing scheduled events, including:
  - Voice channel events
  - Stage events
  - External events (e.g., offline meetups)

  ## Example
      EditScheduledEvent.handler(%{
        guild_id: "123456789",
        event_id: "987654321",
        name: "Updated Game Night",
        description: "Join us for some fun games!",
        scheduled_start_time: "2024-04-01T19:00:00Z",
        scheduled_end_time: "2024-04-01T21:00:00Z",
        entity_type: "voice",
        channel_id: "456789012"
      }, context)
  """

  use Lux.Prism,
    name: "Edit Scheduled Event",
    description: "Edit an existing scheduled event in a Discord guild",
    input_schema: %{
      type: :object,
      required: [:guild_id, :event_id],
      properties: %{
        guild_id: %{type: :string},
        event_id: %{type: :string},
        name: %{type: :string},
        description: %{type: :string},
        scheduled_start_time: %{type: :string},
        scheduled_end_time: %{type: :string},
        entity_type: %{type: :string},
        channel_id: %{type: :string},
        entity_metadata: %{
          type: :object,
          properties: %{
            location: %{type: :string}
          }
        },
        image: %{type: :string}
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        updated: %{type: :boolean},
        event_id: %{type: :string},
        name: %{type: :string}
      }
    }

  require Logger
  alias Lux.Integrations.Discord.Client

  @doc """
  Handles the editing of a scheduled event in a Discord guild.
  """
  def handler(params, %{agent: agent} = _context) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, event_id} <- validate_param(params, :event_id),
         {:ok, entity_type} <- validate_enum_param(params, :entity_type, ["stage_instance", "voice", "external"]),
         :ok <- validate_channel_id(params, entity_type),
         :ok <- validate_entity_metadata(params, entity_type),
         {:ok, request_data} <- build_request_data(params),
         {:ok, response} <- make_api_request(guild_id, event_id, request_data) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} updating scheduled event #{event_id} in guild #{guild_id}")

      {:ok, %{
        updated: true,
        event_id: response["id"],
        name: response["name"]
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
    data = %{}
    |> maybe_add_field(params, "name")
    |> maybe_add_field(params, "description")
    |> maybe_add_field(params, "scheduled_start_time")
    |> maybe_add_field(params, "scheduled_end_time")
    |> maybe_add_entity_type(params)
    |> maybe_add_channel_id(params)
    |> maybe_add_entity_metadata(params)
    |> maybe_add_image(params)
    |> Map.put("privacy_level", 2)  # GUILD_ONLY

    {:ok, data}
  end

  defp maybe_add_field(data, params, field) do
    case Map.get(params, String.to_atom(field)) do
      value when is_binary(value) and value != "" -> Map.put(data, field, value)
      _ -> data
    end
  end

  defp maybe_add_entity_type(data, %{entity_type: type}) do
    Map.put(data, "entity_type", entity_type_to_int(type))
  end
  defp maybe_add_entity_type(data, _), do: data

  defp entity_type_to_int("stage_instance"), do: 1
  defp entity_type_to_int("voice"), do: 2
  defp entity_type_to_int("external"), do: 3

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

  defp make_api_request(guild_id, event_id, request_data) do
    path = "/guilds/#{guild_id}/scheduled-events/#{event_id}"
    plug = Map.get(request_data, :plug)
    opts = %{
      json: request_data,
      plug: plug
    }
    |> Map.reject(fn {_k, v} -> is_nil(v) end)

    case Client.request(:patch, path, opts) do
      {:ok, response} -> {:ok, response}
      {:error, {_status, %{"code" => code, "message" => message}}} -> {:error, %{"code" => code, "message" => message}}
      {:error, {_status, message}} when is_binary(message) -> {:error, %{"code" => 50_013, "message" => message}}
      {:error, error} -> {:error, error}
    end
  end
end
