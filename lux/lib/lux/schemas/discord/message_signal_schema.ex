defmodule Lux.Schemas.Discord.MessageSignalSchema do
  @moduledoc """
  Schema definition for Discord message signals in Lux.
  """

  use Lux.SignalSchema,
    name: "discord_message_signal",
    version: "1.0.0",
    description: "Represents an incoming or outgoing Discord message with rich metadata",
    schema: %{
      type: :object,
      properties: %{
        content: %{type: :string, description: "Message body text"},
        channel_id: %{type: :string, description: "Channel snowflake ID"},
        guild_id: %{type: :string, description: "Guild snowflake ID"},
        message_id: %{type: :string, description: "Message snowflake ID"},
        author: %{
          type: :object,
          properties: %{
            id: %{type: :string},
            username: %{type: :string},
            bot: %{type: :boolean}
          },
          required: ["id", "username"]
        },
        attachments: %{type: :array, description: "Attached media or files"},
        embeds: %{type: :array, description: "Rich embed structures"},
        components: %{type: :array, description: "Action rows, buttons, menus"}
      },
      required: ["channel_id"]
    }
end
