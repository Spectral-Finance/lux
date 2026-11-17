defmodule Lux.Beams.Discord.EventHandlingBeam do
  @moduledoc """
  A beam that orchestrates event handling operations in Discord.

  This beam creates a scheduled event in a guild.

  ## Example Usage

  ```elixir
  {:ok, result, log} = Lux.Beams.Discord.EventHandlingBeam.run(%{
    guild_id: "123456789012345678",
    name: "Community Meetup",
    scheduled_start_time: "2024-12-25T18:00:00Z",
    privacy_level: 2,
    entity_type: 3,
    entity_metadata: %{location: "Discord Stage"}
  })

  # Result:
  %{
    event_id: "111111111111111111",
    name: "Community Meetup",
    guild_id: "123456789012345678"
  }
  ```
  """

  use Lux.Beam,
    name: "Discord Event Handling",
    description: "Creates and manages scheduled events in a Discord guild",
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
          description: "Name of the event",
          minLength: 1,
          maxLength: 100
        },
        description: %{
          type: :string,
          description: "Description of the event",
          maxLength: 1000
        },
        scheduled_start_time: %{
          type: :string,
          description: "ISO8601 start time"
        },
        scheduled_end_time: %{
          type: :string,
          description: "ISO8601 end time"
        },
        privacy_level: %{
          type: :integer,
          description: "Privacy level (2=GUILD_ONLY)",
          enum: [2]
        },
        entity_type: %{
          type: :integer,
          description: "Event type (1=STAGE, 2=VOICE, 3=EXTERNAL)",
          enum: [1, 2, 3]
        },
        channel_id: %{
          type: :string,
          description: "Channel ID for stage/voice events"
        },
        entity_metadata: %{
          type: :object,
          description: "Metadata for external events"
        }
      },
      required: ["guild_id", "name", "scheduled_start_time", "privacy_level", "entity_type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        event_id: %{type: :string, description: "The created event ID"},
        name: %{type: :string, description: "The event name"},
        guild_id: %{type: :string, description: "The guild ID"}
      },
      required: ["event_id", "name", "guild_id"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Discord.Events.CreateScheduledEvent

  sequence do
    step(:create_event, CreateScheduledEvent, %{
      guild_id: [:input, :guild_id],
      name: [:input, :name],
      description: [:input, :description],
      scheduled_start_time: [:input, :scheduled_start_time],
      scheduled_end_time: [:input, :scheduled_end_time],
      privacy_level: [:input, :privacy_level],
      entity_type: [:input, :entity_type],
      channel_id: [:input, :channel_id],
      entity_metadata: [:input, :entity_metadata]
    })

    step(:return, Lux.Prisms.NoOp, %{
      event_id: [:steps, :create_event, :result, :event_id],
      name: [:steps, :create_event, :result, :name],
      guild_id: [:input, :guild_id]
    })
  end
end
