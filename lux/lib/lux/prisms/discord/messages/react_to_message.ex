defmodule Lux.Prisms.Discord.Messages.ReactToMessage do
  @moduledoc """
  A prism for adding a reaction emoji to a Discord message.
  """

  use Lux.Prism,
    name: "React to Discord Message",
    description: "Adds a reaction emoji (Unicode or custom emoji string) to a message",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "Channel snowflake ID"},
        message_id: %{type: :string, description: "Message snowflake ID"},
        emoji: %{type: :string, description: "Reaction emoji (e.g., '👍' or 'custom_emoji:123456789')"}
      },
      required: ["channel_id", "message_id", "emoji"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        reacted: %{type: :boolean},
        channel_id: %{type: :string},
        message_id: %{type: :string},
        emoji: %{type: :string}
      },
      required: ["reacted", "channel_id", "message_id", "emoji"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, message_id} <- validate_param(params, :message_id),
         {:ok, emoji} <- validate_param(params, :emoji) do
      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Agent"
      Logger.info("Agent #{agent_name} reacting with #{emoji} on message #{message_id}")

      encoded_emoji = URI.encode(emoji)
      opts = %{}
      opts = if plug = params[:plug], do: Map.put(opts, :plug, plug), else: opts
      opts = if token = params[:token], do: Map.put(opts, :token, token), else: opts

      case Client.request(:put, "/channels/#{channel_id}/messages/#{message_id}/reactions/#{encoded_emoji}/@me", opts) do
        {:ok, _} ->
          {:ok, %{
            reacted: true,
            emoji: emoji,
            message_id: message_id,
            channel_id: channel_id
          }}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, val} when is_binary(val) and val != "" -> {:ok, val}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
