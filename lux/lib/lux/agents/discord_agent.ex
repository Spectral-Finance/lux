defmodule Lux.Agents.DiscordAgent do
  @moduledoc """
  An autonomous Discord agent that manages server topology, monitors and moderates
  conversations, administers roles and permissions, and engages with members.
  """

  use Lux.Agent,
    name: "Discord Community & Server Management Agent",
    description: "Manages Discord servers, moderates conversations, assigns roles, and interacts with members",
    goal: "Maintain healthy, active Discord communities through autonomous administration, moderation, and member profiling",
    capabilities: [
      :server_management,
      :conversation_moderation,
      :role_assignment,
      :member_interaction
    ],
    prisms: [
      Lux.Prisms.Discord.ServerManagementPrism,
      Lux.Prisms.Discord.ConversationPrism,
      Lux.Prisms.Discord.RoleManagementPrism,
      Lux.Prisms.Discord.MemberInteractionPrism
    ],
    llm_config: %{
      model: "gpt-4o",
      temperature: 0.2,
      json_response: true,
      json_schema: %{
        name: "discord_action_decision",
        schema: %{
          type: "object",
          properties: %{
            action: %{
              type: "string",
              description: "Target action (moderate, reply, assign_role, monitor)"
            },
            reasoning: %{
              type: "string",
              description: "Rationale for the decided behavior"
            },
            target_id: %{
              type: "string",
              description: "Target user_id, channel_id, or role_id"
            }
          },
          required: ["action", "reasoning"],
          additionalProperties: false
        },
        strict: true
      }
    }
end
