defmodule Lux.Beams.Discord.ChannelLifecycleBeam do
  @moduledoc """
  An autonomous workflow beam coordinating Discord channel provisioning:
  1. Creates a new channel in target guild.
  2. Configures role or member permission overwrites.
  3. Publishes an introductory announcement message.
  """

  use Lux.Beam,
    name: "Discord Channel Lifecycle Beam",
    description: "Automates channel creation, permission configuration, and initial announcement",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Guild Snowflake ID"},
        name: %{type: :string, description: "Channel name"},
        type: %{type: :integer, description: "Channel type (0: text, 2: voice)"},
        topic: %{type: :string, description: "Channel topic"},
        role_id: %{type: :string, description: "Role ID for permission overwrite"},
        allow: %{type: :string, description: "Bitwise allow flags"},
        deny: %{type: :string, description: "Bitwise deny flags"},
        welcome_message: %{type: :string, description: "Introductory announcement text"}
      },
      required: ["guild_id", "name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string},
        channel_name: %{type: :string},
        permissions_configured: %{type: :boolean},
        announced: %{type: :boolean}
      },
      required: ["channel_id", "channel_name"]
    }

  alias Lux.Prisms.Discord.{ChannelManagementPrism, MessageManagementPrism}

  def run(input, _context \\ %{}) do
    guild_id = input[:guild_id] || input["guild_id"]
    name = input[:name] || input["name"]
    type = input[:type] || input["type"] || 0
    topic = input[:topic] || input["topic"]
    role_id = input[:role_id] || input["role_id"]
    allow = input[:allow] || input["allow"] || "0"
    deny = input[:deny] || input["deny"] || "0"
    welcome_text = input[:welcome_message] || input["welcome_message"]
    plug = input[:plug] || input["plug"]

    # Step 1: Create channel
    {:ok, %{result: created}} =
      ChannelManagementPrism.run(%{
        action: "create_channel",
        payload: %{
          guild_id: guild_id,
          name: name,
          type: type,
          topic: topic,
          plug: plug
        }
      })

    channel_id = created["id"]

    # Step 2: Set permissions (if role_id supplied)
    permissions_configured =
      if role_id do
        case ChannelManagementPrism.run(%{
          action: "set_permissions",
          payload: %{
            channel_id: channel_id,
            overwrite_id: role_id,
            type: 0,
            allow: allow,
            deny: deny,
            plug: plug
          }
        }) do
          {:ok, _} -> true
          _ -> false
        end
      else
        false
      end

    # Step 3: Send announcement (if welcome_message supplied)
    announced =
      if welcome_text do
        case MessageManagementPrism.run(%{
          action: "create_message",
          payload: %{
            channel_id: channel_id,
            content: welcome_text,
            plug: plug
          }
        }) do
          {:ok, _} -> true
          _ -> false
        end
      else
        false
      end

    {:ok,
     %{
       channel_id: channel_id,
       channel_name: name,
       permissions_configured: permissions_configured,
       announced: announced
     }}
  end
end
