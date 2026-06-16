defmodule Lux.Prisms.Discord.Events.CreateScheduledEvent do
  @moduledoc """
  Creates a scheduled event in a Discord guild.
  """

  use Lux.Prism,
    name: "Create Discord Scheduled Event",
    description: "Creates a guild scheduled event for Discord reminders and community workflows",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Discord guild ID", pattern: "^[0-9]{17,20}$"},
        name: %{type: :string, description: "Event name", minLength: 1, maxLength: 100},
        scheduled_start_time: %{type: :string, description: "ISO8601 event start timestamp"},
        scheduled_end_time: %{type: :string, description: "ISO8601 event end timestamp"},
        description: %{type: :string, description: "Optional event description"},
        channel_id: %{type: :string, description: "Voice/stage channel ID for channel events"},
        entity_type: %{
          type: :integer,
          description: "Discord scheduled event entity type: 2 voice, 3 external",
          enum: [2, 3]
        },
        location: %{type: :string, description: "Required for external events"},
        reason: %{type: :string, description: "Optional Discord audit log reason"}
      },
      required: ["guild_id", "name", "scheduled_start_time", "entity_type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        created: %{type: :boolean, description: "Whether the event was created"},
        event_id: %{type: :string, description: "Discord scheduled event ID"},
        guild_id: %{type: :string, description: "Discord guild ID"},
        name: %{type: :string, description: "Event name"}
      },
      required: ["created"]
    }

  alias Lux.Integrations.Discord.Client

  @guild_only_privacy_level 2

  def handler(params, _agent) do
    with {:ok, guild_id} <- validate_string(params, :guild_id),
         {:ok, name} <- validate_string(params, :name),
         {:ok, start_time} <- validate_string(params, :scheduled_start_time),
         {:ok, entity_type} <- validate_entity_type(params),
         {:ok, body} <- build_body(params, name, start_time, entity_type) do
      opts = %{json: body, headers: audit_headers(params[:reason])}

      case Client.request(:post, "/guilds/#{guild_id}/scheduled-events", opts) do
        {:ok, %{"id" => event_id, "name" => event_name}} ->
          {:ok, %{created: true, event_id: event_id, guild_id: guild_id, name: event_name}}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp build_body(params, name, start_time, 2) do
    with {:ok, channel_id} <- validate_string(params, :channel_id) do
      {:ok,
       %{
         name: name,
         scheduled_start_time: start_time,
         scheduled_end_time: params[:scheduled_end_time],
         description: params[:description],
         channel_id: channel_id,
         entity_type: 2,
         privacy_level: @guild_only_privacy_level
       }
       |> reject_nil_values()}
    end
  end

  defp build_body(params, name, start_time, 3) do
    with {:ok, location} <- validate_string(params, :location) do
      {:ok,
       %{
         name: name,
         scheduled_start_time: start_time,
         scheduled_end_time: params[:scheduled_end_time],
         description: params[:description],
         entity_type: 3,
         privacy_level: @guild_only_privacy_level,
         entity_metadata: %{location: location}
       }
       |> reject_nil_values()}
    end
  end

  defp validate_entity_type(%{entity_type: value}) when value in [2, 3], do: {:ok, value}
  defp validate_entity_type(_params), do: {:error, "Missing or invalid entity_type"}

  defp validate_string(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp reject_nil_values(map) do
    Map.reject(map, fn {_key, value} -> is_nil(value) end)
  end

  defp audit_headers(reason) when is_binary(reason) and reason != "" do
    [{"X-Audit-Log-Reason", URI.encode(reason)}]
  end

  defp audit_headers(_reason), do: []
end
