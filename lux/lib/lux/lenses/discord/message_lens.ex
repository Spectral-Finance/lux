defmodule Lux.Lenses.Discord.MessageLens do
  @moduledoc """
  A lens for reading messages from Discord channels.

  ## Example

      iex> Lux.Lenses.Discord.MessageLens.run(%{
      ...>   channel_id: "123456789",
      ...>   limit: 50
      ...> })
      {:ok, %{
        messages: [
          %{
            id: "987654321",
            content: "Hello, Discord!",
            timestamp: "2024-03-08T12:34:56Z"
          }
        ],
        channel_id: "123456789"
      }}

  The lens reads Discord authentication details from configuration:
  - :discord_token - Discord bot token for authentication
  """

  use Lux.Lens,
    name: "read_messages",
    description: "Read recent messages from a channel",
    schema: %{
      type: "object",
      properties: %{
        channel_id: %{
          type: "string",
          description: "Discord channel ID"
        },
        limit: %{
          type: "number",
          description: "Number of messages to fetch (max 100)",
          minimum: 1,
          maximum: 100
        }
      },
      required: ["channel_id"]
    }

  require Logger

  @doc """
  Focuses on messages in a Discord channel.
  """
  def focus(input, ctx \\ %{})  # Single default declaration

  def focus(%{"channel_id" => channel_id} = input, ctx) do
    limit = Map.get(input, "limit", 50)

    case Nostrum.Api.Channel.messages(String.to_integer(channel_id), limit: limit) do
      {:ok, messages} ->
        {:ok, %{
          messages: Enum.map(messages, fn msg ->
            %{
              id: to_string(msg.id),
              content: msg.content,
              timestamp: msg.timestamp |> DateTime.to_iso8601(),
              author: %{
                id: to_string(msg.author.id),
                username: msg.author.username
              },
              reactions: Enum.map(msg.reactions || [], fn reaction ->
                %{
                  emoji: reaction.emoji.name,
                  count: reaction.count
                }
              end)
            }
          end),
          channel_id: channel_id
        }}

      {:error, %{status_code: status, message: error_message}} ->
        Logger.error("Discord API error: #{status} - #{error_message}")
        {:error, "Failed to fetch messages: #{error_message}"}

      {:error, error} ->
        Logger.error("Discord API request failed: #{inspect(error)}")
        {:error, "Failed to fetch messages: #{inspect(error)}"}
    end
  end

  def focus(input, ctx) do
    {:error, "Missing required field: channel_id"}
  end
end
