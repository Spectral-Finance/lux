defmodule Lux.Signals.DiscordConverter do
  @moduledoc """
  Handles bidirectional conversion between raw Discord gateway/API payloads and Lux.Signal structures.
  """
  
  alias Lux.Signals.DiscordMessage
  alias Lux.Signals.DiscordInteraction
  alias Lux.Signals.DiscordPresence

  # 1. Discord Message conversion
  @doc """
  Converts a raw Discord gateway MESSAGE_CREATE payload to a DiscordMessage signal.
  """
  def to_signal(%{"content" => content, "channel_id" => cid, "author" => %{"id" => aid}} = payload) do
    DiscordMessage.new(%{
      payload: %{
        "content" => content,
        "channel_id" => cid,
        "guild_id" => Map.get(payload, "guild_id", ""),
        "author_id" => aid,
        "attachments" => Enum.map(Map.get(payload, "attachments", []), &(&1["url"] || "")),
        "embeds" => Map.get(payload, "embeds", []),
        "components" => Map.get(payload, "components", [])
      }
    })
  end

  # 2. Discord Interaction conversion
  def to_signal(%{"type" => type_int, "id" => id, "user" => %{"id" => uid}} = payload) do
    type = case type_int do
      1 -> "command"
      2 -> "button"
      3 -> "select_menu"
      4 -> "modal"
      _ -> "button"
    end

    data = Map.get(payload, "data", %{})

    DiscordInteraction.new(%{
      payload: %{
        "type" => type,
        "id" => id,
        "name" => Map.get(data, "name", ""),
        "custom_id" => Map.get(data, "custom_id", ""),
        "values" => Map.get(data, "values", []),
        "user_id" => uid,
        "channel_id" => Map.get(payload, "channel_id", ""),
        "guild_id" => Map.get(payload, "guild_id", "")
      }
    })
  end

  # 3. Discord Presence conversion
  def to_signal(%{"user" => %{"id" => uid}, "status" => status} = payload) do
    DiscordPresence.new(%{
      payload: %{
        "user_id" => uid,
        "status" => status,
        "activities" => Map.get(payload, "activities", []),
        "guild_id" => Map.get(payload, "guild_id", "")
      }
    })
  end

  def to_signal(_), do: {:error, :unsupported_payload_type}

  # 4. Bidirectional conversion: Signal -> Discord payload
  @doc """
  Converts a DiscordMessage signal payload to a Discord REST API request body.
  """
  def to_discord_payload(%Lux.Signal{schema_id: Lux.Schemas.DiscordMessageSchema} = signal) do
    payload = signal.payload
    {:ok, %{
      content: payload[:content] || payload["content"],
      embeds: payload[:embeds] || payload["embeds"] || [],
      components: payload[:components] || payload["components"] || []
    }}
  end
  
  def to_discord_payload(_), do: {:error, :invalid_signal_type}
end
