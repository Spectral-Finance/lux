defmodule Lux.Beams.Discord.ModerationBeam do
  @moduledoc """
  A beam that orchestrates moderation operations in Discord.

  This beam bans a user from a guild with optional message deletion,
  combining ban and audit operations.

  ## Example Usage

  ```elixir
  {:ok, result, log} = Lux.Beams.Discord.ModerationBeam.run(%{
    guild_id: "123456789012345678",
    user_id: "987654321098765432",
    delete_message_seconds: 86400,
    reason: "Repeated spam violations"
  })

  # Result:
  %{
    banned: true,
    user_id: "987654321098765432",
    guild_id: "123456789012345678"
  }
  ```
  """

  use Lux.Beam,
    name: "Discord Moderation",
    description: "Bans a member from a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild",
          pattern: "^[0-9]{17,20}$"
        },
        user_id: %{
          type: :string,
          description: "The ID of the user to ban",
          pattern: "^[0-9]{17,20}$"
        },
        delete_message_seconds: %{
          type: :integer,
          description: "Seconds of messages to delete (0-604800)",
          minimum: 0,
          maximum: 604800
        },
        reason: %{
          type: :string,
          description: "Reason for the moderation action",
          maxLength: 512
        }
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        banned: %{type: :boolean, description: "Whether the user was banned"},
        user_id: %{type: :string, description: "The banned user's ID"},
        guild_id: %{type: :string, description: "The guild ID"}
      },
      required: ["banned", "user_id", "guild_id"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Discord.Moderation.BanMember

  sequence do
    step(:ban_member, BanMember, %{
      guild_id: [:input, :guild_id],
      user_id: [:input, :user_id],
      delete_message_seconds: [:input, :delete_message_seconds],
      reason: [:input, :reason]
    })

    step(:return, Lux.Prisms.NoOp, %{
      banned: [:steps, :ban_member, :result, :banned],
      user_id: [:input, :user_id],
      guild_id: [:input, :guild_id]
    })
  end
end
