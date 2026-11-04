defmodule Lux.Beams.Discord.GuildOperationsBeam do
  @moduledoc """
  A composite Beam that orchestrates end-to-end Discord server management,
  role setup, channel creation, and initial agent announcement (`Spectral-Finance/lux#55`).
  """

  use Lux.Beam,
    name: "Discord Guild Operations Beam",
    description: "Creates a guild channel, configures a custom role, and posts an announcement message",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Target Discord guild ID"},
        channel_name: %{type: :string, description: "Channel name to create"},
        role_name: %{type: :string, description: "Custom role name to create"},
        announcement: %{type: :string, description: "Initial message to post in the created channel"}
      },
      required: ["guild_id", "channel_name", "role_name", "announcement"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string},
        role_id: %{type: :string},
        message_sent: %{type: :boolean}
      },
      required: ["channel_id", "role_id", "message_sent"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Discord.Channels.CreateChannel
  alias Lux.Prisms.Discord.Message.SendMessage
  alias Lux.Prisms.Discord.Roles.ManageRole

  sequence do
    step(:create_channel, CreateChannel, %{
      guild_id: [:input, :guild_id],
      name: [:input, :channel_name],
      type: 0
    })

    step(:create_role, ManageRole, %{
      action: "create",
      guild_id: [:input, :guild_id],
      name: [:input, :role_name],
      permissions: "8"
    })

    step(:post_announcement, SendMessage, %{
      channel_id: [:steps, :create_channel, :result, :channel_id],
      content: [:input, :announcement]
    })
  end
end
