defmodule Lux.Prisms.Discord.Messages.ReactToMessage do
  @moduledoc """
  A prism for adding reactions to messages in a Discord channel.
  Supports both Unicode emojis and custom emojis.
  ## Examples
      # React with Unicode emoji
      iex> ReactToMessage.handler(%{
      ...>   channel_id: "123456789",
      ...>   message_id: "987654321",
      ...>   emoji: "👍"
      ...> }, %{name: "Agent"})
      {:ok, %{reacted: true, emoji: "👍", message_id: "987654321", channel_id: "123456789"}}
      # React with custom emoji
      iex> ReactToMessage.handler(%{
      ...>   channel_id: "123456789",
      ...>   message_id: "987654321",
      ...>   emoji: "custom_emoji:123_456_789"
      ...> }, %{name: "Agent"})
      {:ok, %{reacted: true, emoji: "custom_emoji:123_456_789", message_id: "987654321", channel_id: "123456789"}}
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
        },
        message_id: %{
          type: :string,
          description: "The ID of the message that was reacted to"
        },
        channel_id: %{
          type: :string,
          description: "The ID of the channel containing the message"
        }
      },
      required: ["reacted"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to add a reaction to a message in a Discord channel.
  """
  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, message_id} <- validate_param(params, :message_id),
         {:ok, emoji} <- validate_param(params, :emoji) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} reacting to message #{message_id} in channel #{channel_id} with emoji #{emoji}")

      encoded_emoji = URI.encode(emoji)
      case Client.request(:put, "/channels/#{channel_id}/messages/#{message_id}/reactions/#{encoded_emoji}/@me") do
        {:ok, _} ->
          Logger.info("Successfully reacted to message #{message_id} in channel #{channel_id} with emoji #{emoji}")
          {:ok, %{reacted: true, emoji: emoji, message_id: message_id, channel_id: channel_id}}
        error ->
          Logger.error("Failed to react to message #{message_id} in channel #{channel_id} with emoji #{emoji}: #{inspect(error)}")
          error
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
