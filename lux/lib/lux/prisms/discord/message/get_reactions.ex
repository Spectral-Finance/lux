defmodule Lux.Prisms.Discord.Messages.GetReactions do
  @moduledoc """
  A prism for listing users who reacted to a Discord message with a given emoji.

  This fills the read side of Discord reaction handling, complementing
  ReactToMessage and RemoveReaction.
  """

  use Lux.Prism,
    name: "Get Discord Message Reactions",
    description: "Lists users who reacted to a Discord message with a specific emoji",
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
          description: "The ID of the message to inspect",
          pattern: "^[0-9]{17,20}$"
        },
        emoji: %{
          type: :string,
          description: "The emoji reaction to list users for",
          maxLength: 100
        },
        limit: %{
          type: :integer,
          description: "Max number of users to return (1-100)",
          minimum: 1,
          maximum: 100,
          default: 25
        },
        after: %{
          type: :string,
          description: "Get reaction users after this user ID",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["channel_id", "message_id", "emoji"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        users: %{
          type: :array,
          description: "Discord users who reacted with the requested emoji"
        },
        count: %{
          type: :integer,
          description: "Number of users returned"
        },
        emoji: %{
          type: :string,
          description: "The emoji reaction that was listed"
        },
        message_id: %{
          type: :string,
          description: "The ID of the inspected message"
        },
        channel_id: %{
          type: :string,
          description: "The ID of the channel containing the message"
        }
      },
      required: ["users", "count"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to list users who reacted to a Discord message.
  """
  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, message_id} <- validate_param(params, :message_id),
         {:ok, emoji} <- validate_param(params, :emoji),
         {:ok, limit} <- validate_limit(params),
         {:ok, after_user_id} <- validate_optional_param(params, :after) do
      agent_name = agent[:name] || "Unknown Agent"
      encoded_emoji = URI.encode(emoji)

      Logger.info(
        "Agent #{agent_name} listing reactions #{emoji} for message #{message_id} in channel #{channel_id}"
      )

      path =
        "/channels/#{channel_id}/messages/#{message_id}/reactions/#{encoded_emoji}" <>
          query_string(%{limit: limit, after: after_user_id})

      case Client.request(:get, path) do
        {:ok, users} when is_list(users) ->
          reaction_users = Enum.map(users, &normalize_user/1)

          {:ok,
           %{
             users: reaction_users,
             count: length(reaction_users),
             emoji: emoji,
             message_id: message_id,
             channel_id: channel_id
           }}

        error ->
          Logger.error(
            "Failed to list reactions #{emoji} for message #{message_id} in channel #{channel_id}: #{inspect(error)}"
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

  defp validate_limit(params) do
    case Map.fetch(params, :limit) do
      :error -> {:ok, 25}
      {:ok, value} when is_integer(value) and value >= 1 and value <= 100 -> {:ok, value}
      _ -> {:error, "Missing or invalid limit"}
    end
  end

  defp query_string(params) do
    params
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
    |> URI.encode_query()
    |> case do
      "" -> ""
      query -> "?#{query}"
    end
  end

  defp normalize_user(user) do
    %{
      id: user["id"],
      username: user["username"],
      discriminator: user["discriminator"],
      global_name: user["global_name"],
      bot: Map.get(user, "bot", false)
    }
  end
end
