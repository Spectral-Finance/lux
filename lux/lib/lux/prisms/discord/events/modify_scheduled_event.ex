defmodule Lux.Prisms.Discord.Events.ModifyScheduledEvent do
  @moduledoc """
  A prism for modifying a scheduled event in a Discord guild.

  ## Examples
      iex> ModifyScheduledEvent.handler(%{
      ...>   guild_id: "123456789",
      ...>   event_id: "111111111111111111",
      ...>   name: "Updated Event Name",
      ...>   status: 2
      ...> }, %{name: "Agent"})
      {:ok, %{modified: true, event_id: "111111111111111111", guild_id: "123456789"}}
  """

  use Lux.Prism,
    name: "Modify Discord Scheduled Event",
    description: "Modifies a scheduled event in a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild",
          pattern: "^[0-9]{17,20}$"
        },
        event_id: %{
          type: :string,
          description: "The ID of the scheduled event to modify",
          pattern: "^[0-9]{17,20}$"
        },
        name: %{
          type: :string,
          description: "New name for the event",
          minLength: 1,
          maxLength: 100
        },
        description: %{
          type: :string,
          description: "New description for the event",
          maxLength: 1000
        },
        scheduled_start_time: %{
          type: :string,
          description: "New start time (ISO8601)"
        },
        scheduled_end_time: %{
          type: :string,
          description: "New end time (ISO8601)"
        },
        status: %{
          type: :integer,
          description: "Event status (1=SCHEDULED, 2=ACTIVE, 3=COMPLETED, 4=CANCELED)",
          enum: [1, 2, 3, 4]
        }
      },
      required: ["guild_id", "event_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        modified: %{
          type: :boolean,
          description: "Whether the event was successfully modified"
        },
        event_id: %{
          type: :string,
          description: "The ID of the modified event"
        },
        guild_id: %{
          type: :string,
          description: "The ID of the guild"
        }
      },
      required: ["modified"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @optional_fields ~w(name description scheduled_start_time scheduled_end_time status)a

  @doc """
  Handles the request to modify a scheduled event.

  Returns {:ok, %{modified: true, event_id: id, guild_id: id}} on success.
  Returns {:error, reason} on failure.
  """
  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, event_id} <- validate_param(params, :event_id) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} modifying event #{event_id} in guild #{guild_id}")

      body =
        Enum.reduce(@optional_fields, %{}, fn field, acc ->
          case Map.get(params, field) do
            nil -> acc
            value -> Map.put(acc, field, value)
          end
        end)

      case Client.request(:patch, "/guilds/#{guild_id}/scheduled-events/#{event_id}", %{json: body}) do
        {:ok, _} ->
          Logger.info("Successfully modified event #{event_id} in guild #{guild_id}")
          {:ok, %{modified: true, event_id: event_id, guild_id: guild_id}}
        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to modify event #{event_id} in guild #{guild_id}: #{inspect(error)}")
          {:error, error}
        {:error, error} ->
          Logger.error("Failed to modify event #{event_id} in guild #{guild_id}: #{inspect(error)}")
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
end
