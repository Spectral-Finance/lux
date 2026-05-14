defmodule Lux.Prisms.Discord.Messages.RemoveReaction do
  @moduledoc """
  A prism for removing reactions from Discord messages.

  Supports removing the current bot user's reaction by default, or removing
  another user's reaction when `user_id` is provided.
  """

  use Lux.Prism,
    name: "Remove Discord Message Reaction",
    description: "Removes a reaction from a Discord message",
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
          description: "The ID of the message to remove the reaction from",
          pattern: "^[0-9]{17,20}$"
        },
        emoji: %{
          type: :string,
          description: "The emoji reaction to remove (Unicode emoji or custom emoji ID)",
          maxLength: 100
        },
        user_id: %{
          type: :string,
          description: "Optional Discord user ID whose reaction should be removed; defaults to @me",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["channel_id", "message_id", "emoji"]
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
          description: "The emoji reaction that was removed"
        },
        message_id: %{
          type: :string,
          description: "The ID of the message"
        },
        channel_id: %{
          type: :string,
          description: "The ID of the channel containing the message"
        },
        user_id: %{
          type: :string,
          description: "The user whose reaction was removed, or @me"
        }
      },
      required: ["removed"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to remove a reaction from a Discord message.
  """
  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, message_id} <- validate_param(params, :message_id),
         {:ok, emoji} <- validate_param(params, :emoji),
         {:ok, user_id} <- validate_optional_user_id(params) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} removing #{emoji} reaction from message #{message_id} in channel #{channel_id}")

      encoded_emoji = URI.encode(emoji)
      path = "/channels/#{channel_id}/messages/#{message_id}/reactions/#{encoded_emoji}/#{user_id}"

      case Client.request(:delete, path) do
        {:ok, _} ->
          Logger.info("Successfully removed #{emoji} reaction from message #{message_id} in channel #{channel_id}")
          {:ok, %{removed: true, emoji: emoji, message_id: message_id, channel_id: channel_id, user_id: user_id}}

        error ->
          Logger.error("Failed to remove reaction from message #{message_id} in channel #{channel_id}: #{inspect(error)}")
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

  defp validate_optional_user_id(params) do
    case Map.get(params, :user_id) || Map.get(params, "user_id") do
      nil -> {:ok, "@me"}
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid user_id"}
    end
  end
end
