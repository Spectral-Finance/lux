defmodule Lux.Beams.Discord.ChannelManagementBeam do
  @moduledoc """
  A beam that orchestrates channel management operations in Discord.

  This beam creates a channel in a guild and sets up permission overwrites,
  combining the CreateChannel and EditChannelPermissions prisms.

  ## Example Usage

  ```elixir
  {:ok, result, log} = Lux.Beams.Discord.ChannelManagementBeam.run(%{
    guild_id: "123456789012345678",
    name: "team-chat",
    type: 0,
    overwrite_id: "987654321098765432",
    overwrite_type: 0,
    allow: "1024",
    deny: "2048"
  })

  # Result:
  %{
    channel_id: "111111111111111111",
    name: "team-chat",
    guild_id: "123456789012345678",
    permissions_set: true
  }
  ```
  """

  use Lux.Beam,
    name: "Discord Channel Management",
    description: "Creates a channel and configures its permissions",
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
          description: "Name of the channel to create",
          minLength: 1,
          maxLength: 100
        },
        type: %{
          type: :integer,
          description: "Channel type (0=text, 2=voice, 13=stage, 15=forum)",
          enum: [0, 2, 13, 15]
        },
        overwrite_id: %{
          type: :string,
          description: "Role or user ID for permission overwrite"
        },
        overwrite_type: %{
          type: :integer,
          description: "0 for role, 1 for member"
        },
        allow: %{
          type: :string,
          description: "Allowed permissions bitfield"
        },
        deny: %{
          type: :string,
          description: "Denied permissions bitfield"
        }
      },
      required: ["guild_id", "name", "type", "overwrite_id", "overwrite_type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "The ID of the created channel"},
        name: %{type: :string, description: "The name of the channel"},
        guild_id: %{type: :string, description: "The ID of the guild"},
        permissions_set: %{type: :boolean, description: "Whether permissions were applied"}
      },
      required: ["channel_id", "name", "guild_id"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Discord.Channels.CreateChannel
  alias Lux.Prisms.Discord.Channels.EditChannelPermissions

  sequence do
    step(:create_channel, CreateChannel, %{
      guild_id: [:input, :guild_id],
      name: [:input, :name],
      type: [:input, :type]
    })

    step(:set_permissions, EditChannelPermissions, %{
      channel_id: [:steps, :create_channel, :result, :channel_id],
      overwrite_id: [:input, :overwrite_id],
      type: [:input, :overwrite_type],
      allow: [:input, :allow],
      deny: [:input, :deny]
    })

    step(:return, Lux.Prisms.NoOp, %{
      channel_id: [:steps, :create_channel, :result, :channel_id],
      name: [:input, :name],
      guild_id: [:input, :guild_id],
      permissions_set: true
    })
  end
end
