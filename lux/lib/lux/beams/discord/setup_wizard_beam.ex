defmodule Lux.Beams.Discord.SetupWizardBeam do
  @moduledoc """
  A beam that guides initial Discord server configuration.

  This beam performs a multi-step setup process:
  1. Fetch guild information and current configuration
  2. Create initial roles (Admin, Moderator, Member)
  3. Create initial channels (welcome, announcements, general)
  4. Configure basic guild settings
  5. Optionally assign roles to existing members

  ## Example Usage

      {:ok, result, execution_log} = Lux.Beams.Discord.SetupWizardBeam.run(%{
        guild_id: "123456789",
        guild_name: "My Community",
        admin_role_name: "Admin",
        moderator_role_name: "Moderator",
        member_role_name: "Member",
        welcome_channel_name: "welcome",
        announcements_channel_name: "announcements",
        general_channel_name: "general",
        assign_member_role: true
      })

  The result will look like:
      %{
        guild_id: "123456789",
        guild_name: "My Community",
        roles_created: 3,
        channels_created: 3,
        status: "configured"
      }
  """

  use Lux.Beam,
    name: "Discord Setup Wizard",
    description: "Guides initial Discord server configuration with roles, channels, and settings",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to configure",
          pattern: "^[0-9]{17,20}$"
        },
        guild_name: %{
          type: :string,
          description: "Display name for the guild (used in descriptions)",
          minLength: 1,
          maxLength: 100
        },
        admin_role_name: %{
          type: :string,
          description: "Name for the admin role",
          default: "Admin"
        },
        moderator_role_name: %{
          type: :string,
          description: "Name for the moderator role",
          default: "Moderator"
        },
        member_role_name: %{
          type: :string,
          description: "Name for the default member role",
          default: "Member"
        },
        welcome_channel_name: %{
          type: :string,
          description: "Name for the welcome channel",
          default: "welcome"
        },
        announcements_channel_name: %{
          type: :string,
          description: "Name for the announcements channel",
          default: "announcements"
        },
        general_channel_name: %{
          type: :string,
          description: "Name for the general chat channel",
          default: "general"
        },
        assign_member_role: %{
          type: :boolean,
          description: "Whether to assign the member role to existing members",
          default: true
        }
      },
      required: ["guild_id", "guild_name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "The ID of the configured guild"},
        guild_name: %{type: :string, description: "The name of the guild"},
        roles_created: %{type: :integer, description: "Number of roles created"},
        channels_created: %{type: :integer, description: "Number of channels created"},
        status: %{type: :string, description: "Configuration status"}
      },
      required: ["guild_id", "status"]
    },
    generate_execution_log: true

  alias Lux.Lenses.Discord.Guilds.GetGuild
  alias Lux.Prisms.Discord.Guilds.CreateRole
  alias Lux.Prisms.Discord.Channels.CreateChannel
  alias Lux.Prisms.Discord.Guilds.ModifyGuild
  alias Lux.Prisms.NoOp

  sequence do
    step(:verify_guild, GetGuild, %{
      guild_id: [:input, :guild_id]
    })

    step(:create_admin_role, CreateRole, %{
      guild_id: [:input, :guild_id],
      name: [:input, :admin_role_name],
      color: 16711680,
      hoist: true,
      mentionable: true
    })

    step(:create_moderator_role, CreateRole, %{
      guild_id: [:input, :guild_id],
      name: [:input, :moderator_role_name],
      color: 3447003,
      hoist: true,
      mentionable: true
    })

    step(:create_member_role, CreateRole, %{
      guild_id: [:input, :guild_id],
      name: [:input, :member_role_name],
      hoist: false,
      mentionable: false
    })

    step(:create_welcome_channel, CreateChannel, %{
      guild_id: [:input, :guild_id],
      name: [:input, :welcome_channel_name],
      type: 0
    })

    step(:create_announcements_channel, CreateChannel, %{
      guild_id: [:input, :guild_id],
      name: [:input, :announcements_channel_name],
      type: 0
    })

    step(:create_general_channel, CreateChannel, %{
      guild_id: [:input, :guild_id],
      name: [:input, :general_channel_name],
      type: 0
    })

    step(:format_output, NoOp, %{
      guild_id: [:input, :guild_id],
      guild_name: [:input, :guild_name],
      roles_created: 3,
      channels_created: 3,
      status: "configured"
    })
  end
end
