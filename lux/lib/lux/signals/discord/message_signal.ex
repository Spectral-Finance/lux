defmodule Lux.Signals.Discord.MessageSignal do
  @moduledoc "Discord message signal schema with bidirectional conversion."

  @enforce_keys [:content]
  defstruct [:content, :author, :channel_id, :guild_id, :attachments, :embeds, :components, :metadata, :timestamp]

  @type t :: %__MODULE__{
    content: String.t(),
    author: map() | nil,
    channel_id: String.t() | nil,
    guild_id: String.t() | nil,
    attachments: list(),
    embeds: list(),
    components: list(),
    metadata: map() | nil,
    timestamp: DateTime.t() | nil
  }

  def new(attrs) when is_map(attrs) do
    case Map.get(attrs, :content) || Map.get(attrs, "content") do
      nil -> {:error, :content_required}
      content ->
        {:ok, %__MODULE__{
          content: content,
          author: attrs[:author] || attrs["author"],
          channel_id: attrs[:channel_id] || attrs["channel_id"],
          guild_id: attrs[:guild_id] || attrs["guild_id"],
          attachments: attrs[:attachments] || attrs["attachments"] || [],
          embeds: attrs[:embeds] || attrs["embeds"] || [],
          components: attrs[:components] || attrs["components"] || [],
          metadata: attrs[:metadata] || attrs["metadata"],
          timestamp: DateTime.utc_now()
        }}
    end
  end

  def to_discord(%__MODULE__{} = signal) do
    %{
      "content" => signal.content,
      "channel_id" => signal.channel_id,
      "embeds" => signal.embeds,
      "components" => signal.components
    }
  end

  def from_discord(payload) when is_map(payload) do
    new(%{
      content: payload["content"],
      author: payload["author"],
      channel_id: payload["channel_id"],
      guild_id: payload["guild_id"],
      attachments: payload["attachments"] || [],
      embeds: payload["embeds"] || [],
      components: payload["components"] || []
    })
  end

  def validate(%__MODULE__{content: c}) when is_binary(c) and byte_size(c) > 0, do: :ok
  def validate(_), do: {:error, :invalid_content}
end
