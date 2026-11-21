defmodule Lux.Prisms.Discord.Events.CreateScheduledEvent do
  @moduledoc """
  A prism for creating a scheduled event in a Discord guild.

  Implements the EventHandlingPrism requirements of lux issue #57: creating
  guild scheduled events (external, stage, or voice-channel events).

  ## Examples
      iex> CreateScheduledEvent.handler(%{
      ...>   guild_id: "123456789012345678",
      ...>   name: "Community Standup",
      ...>   scheduled_start_time: "2026-12-01T10:00:00Z",
      ...>   entity_type: 3,
      ...>   description: "Weekly sync"
      ...> }, %{name: "Agent"})
      {:ok, %{scheduled: true, event_id: "111111111111111111", name: "Community Standup"}}
  """

  use Lux.Prism,
    name: "Create Discord Scheduled Event",
    description: "Creates a scheduled event in a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "The ID of the guild", pattern: "^[0-9]{17,20}$"},
        name: %{type: :string, description: "The event name", minLength: 1, maxLength: 100},
        scheduled_start_time: %{
          type: :string,
          description: "ISO-8601 start time (e.g. 2026-12-01T10:00:00Z)"
        },
        entity_type: %{
          type: :integer,
          description: "Event entity type: 1=stage, 2=voice, 3=external",
          minimum: 1,
          maximum: 3
        },
        channel_id: %{type: :string, description: "Voice/stage channel ID (for entity_type 1/2)"},
        description: %{type: :string, description: "Optional event description"}
      },
      required: ["guild_id", "name", "scheduled_start_time"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        scheduled: %{type: :boolean, description: "Whether the event was created"},
        event_id: %{type: :string, description: "The created event ID"},
        name: %{type: :string, description: "The event name"}
      },
      required: ["scheduled"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_id(params, :guild_id),
         {:ok, name} <- validate_name(params, :name),
         {:ok, start_time} <- validate_start_time(params, :scheduled_start_time) do
      agent_name = agent[:name] || "Unknown Agent"

      Logger.info("Agent #{agent_name} creating scheduled event '#{name}' in guild #{guild_id}")

      body = build_body(params, name, start_time)

      case Client.request(:post, "/guilds/#{guild_id}/scheduled-events", %{json: body}) do
        {:ok, %{"id" => event_id}} ->
          Logger.info("Successfully created scheduled event #{event_id} in guild #{guild_id}")

          {:ok, %{scheduled: true, event_id: event_id, name: name}}

        {:error, {status, %{"message" => message}}} ->
          Logger.error("Failed to create scheduled event: #{inspect({status, message})}")
          {:error, {status, message}}

        {:error, error} ->
          Logger.error("Failed to create scheduled event: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp build_body(params, name, start_time) do
    body = %{
      name: name,
      scheduled_start_time: start_time,
      entity_type: Map.get(params, :entity_type, 3),
      privacy_level: 2
    }

    body =
      case Map.fetch(params, :channel_id) do
        {:ok, channel_id} when is_binary(channel_id) and channel_id != "" ->
          Map.put(body, :channel_id, channel_id)

        _ ->
          body
      end

    case Map.fetch(params, :description) do
      {:ok, description} when is_binary(description) and description != "" ->
        Map.put(body, :description, description)

      _ ->
        body
    end
  end

  defp validate_id(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_name(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_start_time(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" ->
        {:ok, value}

      _ ->
        {:error, "Missing or invalid #{key}"}
    end
  end
end