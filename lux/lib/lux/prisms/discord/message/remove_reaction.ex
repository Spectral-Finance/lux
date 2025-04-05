defmodule Lux.Prisms.Discord.Messages.RemoveReaction do
  @moduledoc """
  A prism for removing reactions from messages in a Discord channel.
  Supports both Unicode emojis and custom emojis.

  ## Examples
      # Remove Unicode emoji reaction
      iex> RemoveReaction.handler(%{
      ...>   channel_id: "123456789",
      ...>   message_id: "987654321",
      ...>   user_id: "111111111",
      ...>   emoji: "👍"
      ...> }, %{name: "Agent"})
      {:ok, %{removed: true, emoji: "👍", message_id: "987654321", channel_id: "123456789", user_id: "111111111"}}

      # Remove custom emoji reaction
      iex> RemoveReaction.handler(%{
      ...>   channel_id: "123456789",
      ...>   message_id: "987654321",
      ...>   user_id: "111111111",
      ...>   emoji: "custom_emoji:123456789"
      ...> }, %{name: "Agent"})
      {:ok, %{removed: true, emoji: "custom_emoji:123456789", message_id: "987654321", channel_id: "123456789", user_id: "111111111"}}
  """

  use Lux.Prism,
    name: "Remove Discord Message Reaction",
    description: "Removes a specific user's reaction from a message in a Discord channel",
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
          description: "The ID of the message to remove reaction from",
          pattern: "^[0-9]{17,20}$"
        },
        user_id: %{
          type: :string,
          description: "The ID of the user whose reaction to remove",
          pattern: "^[0-9]{17,20}$"
        },
        emoji: %{
          type: :string,
          description: "The emoji to remove (Unicode emoji or custom emoji ID)",
          maxLength: 100
        }
      },
      required: ["channel_id", "message_id", "user_id", "emoji"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        removed: %{
          type: :boolean,
          description: "Whether the reaction was successfully removed"
        },
        emoji: %{
          type: :string,
          description: "The emoji that was removed"
        },
        message_id: %{
          type: :string,
          description: "The ID of the message that had the reaction removed"
        },
        channel_id: %{
          type: :string,
          description: "The ID of the channel containing the message"
        },
        user_id: %{
          type: :string,
          description: "The ID of the user whose reaction was removed"
        }
      },
      required: ["removed"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to remove a reaction from a message in a Discord channel.

  Returns {:ok, %{removed: true, emoji: emoji, message_id: message_id, channel_id: channel_id, user_id: user_id}} on success.
  Returns {:error, {status, message}} on failure.
  """
  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, message_id} <- validate_param(params, :message_id),
         {:ok, user_id} <- validate_param(params, :user_id),
         {:ok, emoji} <- validate_param(params, :emoji) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} removing reaction #{emoji} by user #{user_id} from message #{message_id} in channel #{channel_id}")

      encoded_emoji = URI.encode(emoji)
      case Client.request(:delete, "/channels/#{channel_id}/messages/#{message_id}/reactions/#{encoded_emoji}/#{user_id}") do
        {:ok, _} ->
          Logger.info("Successfully removed reaction #{emoji} by user #{user_id} from message #{message_id} in channel #{channel_id}")
          {:ok, %{removed: true, emoji: emoji, message_id: message_id, channel_id: channel_id, user_id: user_id}}
        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to remove reaction #{emoji} by user #{user_id} from message #{message_id} in channel #{channel_id}: #{inspect(error)}")
          {:error, error}
        {:error, error} ->
          Logger.error("Failed to remove reaction #{emoji} by user #{user_id} from message #{message_id} in channel #{channel_id}: #{inspect(error)}")
          {:error, error}
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
