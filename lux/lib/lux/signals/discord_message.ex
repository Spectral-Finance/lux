defmodule Lux.Signals.DiscordMessage do
  @moduledoc """
  Signal representing a Discord message event.
  Supports bidirectional conversion between raw Discord Gateway/Webhook event maps and typed Lux signals.
  """

  use Lux.Signal,
    schema_id: Lux.Schemas.DiscordMessageSchema

  @doc """
  Parses a raw Discord message payload/event into a validated `Lux.Signal` struct.
  """
  def from_event(raw) when is_map(raw) do
    author_raw = raw["author"] || raw[:author] || %{}

    author = %{
      "id" => to_string(author_raw["id"] || author_raw[:id] || ""),
      "username" => to_string(author_raw["username"] || author_raw[:username] || "unknown"),
      "discriminator" => to_string(author_raw["discriminator"] || author_raw[:discriminator] || "0"),
      "avatar" => author_raw["avatar"] || author_raw[:avatar],
      "bot" => author_raw["bot"] || author_raw[:bot] || false
    }

    attachments =
      Enum.map(raw["attachments"] || raw[:attachments] || [], fn att ->
        %{
          "id" => to_string(att["id"] || att[:id] || ""),
          "filename" => to_string(att["filename"] || att[:filename] || ""),
          "url" => to_string(att["url"] || att[:url] || ""),
          "size" => att["size"] || att[:size] || 0,
          "content_type" => att["content_type"] || att[:content_type] || "application/octet-stream"
        }
      end)

    embeds =
      Enum.map(raw["embeds"] || raw[:embeds] || [], fn emb ->
        fields =
          Enum.map(emb["fields"] || emb[:fields] || [], fn f ->
            %{
              "name" => to_string(f["name"] || f[:name] || ""),
              "value" => to_string(f["value"] || f[:value] || ""),
              "inline" => f["inline"] || f[:inline] || false
            }
          end)

        %{
          "title" => emb["title"] || emb[:title],
          "description" => emb["description"] || emb[:description],
          "url" => emb["url"] || emb[:url],
          "color" => emb["color"] || emb[:color],
          "fields" => fields
        }
        |> Enum.reject(fn {_, v} -> is_nil(v) end)
        |> Map.new()
      end)

    payload =
      %{
        "id" => to_string(raw["id"] || raw[:id] || ""),
        "channel_id" => to_string(raw["channel_id"] || raw[:channel_id] || ""),
        "guild_id" => (raw["guild_id"] || raw[:guild_id]) && to_string(raw["guild_id"] || raw[:guild_id]),
        "content" => to_string(raw["content"] || raw[:content] || ""),
        "author" => author,
        "attachments" => attachments,
        "embeds" => embeds,
        "components" => raw["components"] || raw[:components] || [],
        "timestamp" => raw["timestamp"] || raw[:timestamp] || DateTime.to_iso8601(DateTime.utc_now()),
        "tts" => raw["tts"] || raw[:tts] || false
      }
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Map.new()

    new(%{
      sender: author["username"],
      topic: "discord.message.#{payload["channel_id"]}",
      payload: payload,
      metadata: %{
        platform: "discord",
        event_type: "MESSAGE_CREATE",
        guild_id: payload["guild_id"]
      }
    })
  end

  @doc """
  Converts a `Lux.Signal` struct or payload map back into standard Discord JSON event format.
  """
  def to_event(%Lux.Signal{payload: payload}), do: to_event(payload)
  def to_event(payload) when is_map(payload) do
    %{
      "id" => payload["id"] || payload[:id],
      "channel_id" => payload["channel_id"] || payload[:channel_id],
      "guild_id" => payload["guild_id"] || payload[:guild_id],
      "content" => payload["content"] || payload[:content],
      "author" => payload["author"] || payload[:author],
      "attachments" => payload["attachments"] || payload[:attachments] || [],
      "embeds" => payload["embeds"] || payload[:embeds] || [],
      "components" => payload["components"] || payload[:components] || [],
      "timestamp" => payload["timestamp"] || payload[:timestamp],
      "tts" => payload["tts"] || payload[:tts] || false
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end
end
