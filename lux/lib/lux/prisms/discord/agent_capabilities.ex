defmodule Lux.Prisms.Discord.AgentCapabilities do
  @moduledoc """
  Prism wrapper for Discord agent capability planning.
  """

  use Lux.Prism,
    name: "Discord Agent Capabilities",
    description:
      "Builds server, conversation, role, and member interaction plans for Discord agents",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Discord guild ID"},
        channel_id: %{type: :string, description: "Discord channel ID"},
        member_id: %{type: :string, description: "Discord member/user ID"},
        role_id: %{type: :string, description: "Discord role ID"},
        agent_roles: %{
          type: :array,
          description: "Agent behavior roles such as admin, moderator, or member"
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        server_management: %{type: :object},
        conversation_management: %{type: :object},
        role_management: %{type: :object},
        member_interaction: %{type: :object},
        behavior_policy: %{type: :object},
        safety: %{type: :object}
      },
      required: [
        "server_management",
        "conversation_management",
        "role_management",
        "member_interaction"
      ]
    }

  alias Lux.Integrations.Discord.AgentCapabilities

  @impl true
  def handler(input, _context) when is_map(input) do
    {:ok, AgentCapabilities.plan(input)}
  end
end
