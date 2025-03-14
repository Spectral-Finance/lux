defmodule Lux.Prisms.Discord.MessagePrism do
  @moduledoc """
  A prism for sending messages to Discord channels.

  ## Example

      iex> Lux.Prisms.Discord.MessagePrism.run(%{
      ...>   channel_id: "123456789",
      ...>   content: "Hello, Discord!"
      ...> })
      {:ok, %{
        status: "sent",
        message_id: "987654321",
        channel_id: "123456789",
        content: "Hello, Discord!"
      }}

  The prism reads Discord authentication details from configuration:
  - :discord_token - Discord bot token for authentication
  """

  use Lux.Prism,
    name: "send_message",
    description: "Send a message to a specific channel",
    input_schema: %{
      type: "object",
      properties: %{
        channel_id: %{
          type: "string",
          description: "Discord channel ID"
        },
        content: %{
          type: "string",
          description: "Message content"
        }
      },
      required: ["channel_id", "content"]
    }

  require Logger

  @doc """
  Handles sending a message to a Discord channel.
  """
  def handler(%{"content" => content, "channel_id" => channel_id}, _ctx) do
    case Nostrum.Api.Message.create(String.to_integer(channel_id), content) do
      {:ok, message} ->
        {:ok, %{
          status: "sent",
          message_id: to_string(message.id),
          channel_id: to_string(message.channel_id),
          content: message.content
        }}

      {:error, %{status_code: status, message: error_message}} ->
        Logger.error("Discord API error: #{status} - #{error_message}")
        {:error, "Failed to send message: #{error_message}"}

      {:error, error} ->
        Logger.error("Discord API request failed: #{inspect(error)}")
        {:error, "Failed to send message: #{inspect(error)}"}
    end
  end

  def handler(_input, _ctx) do
    {:error, "Missing required fields: content, channel_id"}
  end
end
