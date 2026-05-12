defmodule Lux.Prisms.Discord.Messages.RemoveReaction do
  @moduledoc """
  A prism for removing reactions from Discord messages.

  Supports removing the bot's own reaction or, when a user ID is supplied,
  removing another user's reaction with the proper Discord permissions.
  """

  use Lux.Prism,
    name: "Remove Discord Message Reaction",
    description: "Removes a reaction from a Discord message for the bot or a specific user",
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
          description: "The emoji reaction to remove",
          maxLength: 100
        },
        user_id: %{
          type: :string,
          description: "Optional Discord user ID. When omitted, removes the bot's own reaction.",
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
          description: "The ID of the message the reaction was removed from"
        },
        channel_id: %{
          type: :string,
          description: "The ID of the channel containing the message"
        },
        target: %{
          type: :string,
          description: "The target reaction owner: self or a Discord user ID"
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
         {:ok, user_id} <- validate_optional_param(params, :user_id) do
      agent_name = agent[:name] || "Unknown Agent"
      target = target_segment(user_id)
      encoded_emoji = URI.encode(emoji)

      Logger.info(
        "Agent #{agent_name} removing reaction #{emoji} from message #{message_id} in channel #{channel_id}"
      )

      case Client.request(
             :delete,
             "/channels/#{channel_id}/messages/#{message_id}/reactions/#{encoded_emoji}/#{target}"
           ) do
        {:ok, _} ->
          Logger.info(
            "Successfully removed reaction #{emoji} from message #{message_id} in channel #{channel_id}"
          )

          {:ok,
           %{
             removed: true,
             emoji: emoji,
             message_id: message_id,
             channel_id: channel_id,
             target: target_name(user_id)
           }}

        error ->
          Logger.error(
            "Failed to remove reaction #{emoji} from message #{message_id} in channel #{channel_id}: #{inspect(error)}"
          )

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

  defp validate_optional_param(params, key) do
    case Map.fetch(params, key) do
      :error -> {:ok, nil}
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp target_segment(nil), do: "@me"
  defp target_segment(user_id), do: user_id

  defp target_name(nil), do: "self"
  defp target_name(user_id), do: user_id
end
