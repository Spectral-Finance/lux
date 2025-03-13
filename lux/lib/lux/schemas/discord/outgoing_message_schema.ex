defmodule Lux.Schemas.Discord.OutgoingMessageSchema do
  @moduledoc """
  Schema for sending messages to Discord channels.
  Reference: https://discord.com/developers/docs/resources/channel#create-message
  """
  use Lux.SignalSchema,
    name: "discord_outgoing_message",
    version: "1.0.0",
    description: "Represents a message to be sent to a Discord channel",
    schema: %{
      type: :object,
      properties: %{
        content: %{
          type: :string,
          description: "The message content to send",
          maxLength: 2000
        },
        channel_id: %{
          type: :string,
          description: "The ID of the channel to send the message to"
        }
      },
      required: ["content", "channel_id"]
    }
end
