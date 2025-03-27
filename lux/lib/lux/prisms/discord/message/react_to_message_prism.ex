defmodule Lux.Prisms.Discord.Messages.ReactToMessagePrism do
  @moduledoc """
  A prism for adding reactions to messages in a Discord channel.
  Supports both Unicode emojis and custom emojis.
  ## Examples
      # React with Unicode emoji
      iex> ReactToMessagePrism.handler(%{
      ...>   channel_id: "123456789",
      ...>   message_id: "987654321",
      ...>   emoji: "👍"
      ...> }, %{agent: %{name: "Agent"}})
      {:ok, %{reacted: true}}
      # React with custom emoji
      iex> ReactToMessagePrism.handler(%{
      ...>   channel_id: "123456789",
      ...>   message_id: "987654321",
      ...>   emoji: "custom_emoji:123456789"
      ...> }, %{agent: %{name: "Agent"}})
      {:ok, %{reacted: true}}
  """

  use Lux.Prism,
    name: "React to Discord Message",
    description: "Adds a reaction to a message in a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel containing the message",
          pattern: "^[0-9]{17,20}$"
        },
        message_id: %{
          type: :string,
          description: "The ID of the message to react to",
          pattern: "^[0-9]{17,20}$"
        },
        emoji: %{
          type: :string,
          description: "The emoji to react with (Unicode emoji or custom emoji ID)",
          maxLength: 100
        }
      },
      required: ["channel_id", "message_id", "emoji"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        reacted: %{
          type: :boolean,
          description: "Whether the reaction was successfully added"
        },
        emoji: %{
          type: :string,
          description: "The emoji that was added as a reaction"
        }
      },
      required: ["reacted"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to add a reaction to a message in a Discord channel.
  """
  def handler(%{channel_id: channel_id, message_id: message_id, emoji: emoji}, %{agent: agent} = _ctx) do
    Logger.info("Agent #{agent.name} reacting to message #{message_id} in channel #{channel_id} with emoji #{emoji}")

    encoded_emoji = URI.encode(emoji)
    case Client.request(:put, "/channels/#{channel_id}/messages/#{message_id}/reactions/#{encoded_emoji}/@me", %{}) do
      {:ok, _} ->
        Logger.info("Successfully reacted to message #{message_id} in channel #{channel_id} with emoji #{emoji}")
        {:ok, %{reacted: true, emoji: emoji}}
      error -> error
    end
  end
end
