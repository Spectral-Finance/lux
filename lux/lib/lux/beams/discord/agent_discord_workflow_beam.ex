defmodule Lux.Beams.Discord.AgentDiscordWorkflowBeam do
  @moduledoc """
  A Beam pipeline for executing autonomous Discord agent operational cycles:
  1. Audits server topology and health state (`ServerManagementPrism`).
  2. Retrieves recent conversation message history (`ConversationPrism`).
  3. Evaluates conversation velocity and sentiment analytics (`ConversationPrism`).
  4. Profiles active member metadata and role permissions (`MemberInteractionPrism`).

  ## Example Usage

  ```elixir
  {:ok, result} = Lux.Beams.Discord.AgentDiscordWorkflowBeam.run(%{
    guild_id: "123456789012345678",
    channel_id: "234567890123456789",
    user_id: "345678901234567890"
  })
  ```
  """

  use Lux.Beam,
    name: "Agent Discord Workflow Beam",
    description: "Orchestrates server audit, conversation monitoring, and member profiling for Discord agents",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Discord Guild ID"},
        channel_id: %{type: :string, description: "Discord Channel ID"},
        user_id: %{type: :string, description: "Discord User ID"}
      },
      required: ["guild_id", "channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string},
        channel_id: %{type: :string},
        status: %{type: :string}
      },
      required: ["guild_id", "status"]
    }

  alias Lux.Prisms.Discord.ConversationPrism
  alias Lux.Prisms.Discord.MemberInteractionPrism
  alias Lux.Prisms.Discord.ServerManagementPrism

  sequence do
    step(:audit_server, ServerManagementPrism, %{
      action: "get_guild",
      guild_id: [:input, :guild_id]
    })

    step(:fetch_messages, ConversationPrism, %{
      action: "fetch_history",
      channel_id: [:input, :channel_id]
    })

    step(:analyze_sentiment, ConversationPrism, %{
      action: "analyze_flow",
      channel_id: [:input, :channel_id]
    })

    step(:profile_member, MemberInteractionPrism, %{
      action: "get_member",
      guild_id: [:input, :guild_id],
      user_id: [:input, :user_id]
    })
  end
end
