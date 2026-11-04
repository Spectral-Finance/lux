defmodule Lux.Signals.Discord.Converter do
  @moduledoc """
  Bidirectional converter translating raw Discord gateway/REST payloads to Lux Signals
  and vice versa.
  """

  alias Lux.Signals.Discord.InteractionSignal
  alias Lux.Signals.Discord.MessageSignal
  alias Lux.Signals.Discord.PresenceSignal
  alias Lux.Signals.Discord.VoiceSignal

  @doc """
  Converts a raw Discord Gateway dispatch event map into a strongly typed Lux Signal.
  """
  @spec to_signal(String.t() | atom(), map()) :: {:ok, Lux.Signal.t()} | {:error, term()}
  def to_signal(event_type, data) when is_binary(event_type) do
    case event_type do
      "MESSAGE_CREATE" ->
        payload = %{
          content: Map.get(data, "content", ""),
          channel_id: Map.get(data, "channel_id", ""),
          guild_id: Map.get(data, "guild_id"),
          message_id: Map.get(data, "id"),
          author: %{
            id: get_in(data, ["author", "id"]) || "unknown",
            username: get_in(data, ["author", "username"]) || "anonymous",
            bot: get_in(data, ["author", "bot"]) || false
          },
          attachments: Map.get(data, "attachments", []),
          embeds: Map.get(data, "embeds", []),
          components: Map.get(data, "components", [])
        }

        MessageSignal.new(payload)

      "INTERACTION_CREATE" ->
        raw_type = Map.get(data, "type", 2)
        type_str = parse_interaction_type(raw_type)

        payload = %{
          interaction_id: Map.get(data, "id", "i_#{System.system_time(:millisecond)}"),
          type: type_str,
          name: get_in(data, ["data", "name"]) || "action",
          user_id: get_in(data, ["user", "id"]) || get_in(data, ["member", "user", "id"]) || "anon",
          channel_id: Map.get(data, "channel_id"),
          guild_id: Map.get(data, "guild_id"),
          data: Map.get(data, "data", %{})
        }

        InteractionSignal.new(payload)

      "PRESENCE_UPDATE" ->
        payload = %{
          user_id: get_in(data, ["user", "id"]) || "unknown",
          guild_id: Map.get(data, "guild_id"),
          status: Map.get(data, "status", "online"),
          activities: Map.get(data, "activities", [])
        }

        PresenceSignal.new(payload)

      "VOICE_STATE_UPDATE" ->
        action =
          cond do
            Map.get(data, "channel_id") == nil -> "leave"
            Map.get(data, "self_mute") == true -> "mute"
            Map.get(data, "self_deaf") == true -> "deaf"
            true -> "join"
          end

        payload = %{
          user_id: Map.get(data, "user_id", "unknown"),
          guild_id: Map.get(data, "guild_id", "default"),
          channel_id: Map.get(data, "channel_id"),
          action: action,
          speaking: Map.get(data, "speaking", false)
        }

        VoiceSignal.new(payload)

      unknown ->
        {:error, "Unsupported Discord event type: #{inspect(unknown)}"}
    end
  end

  def to_signal(event_type, data) when is_atom(event_type) do
    to_signal(to_string(event_type), data)
  end

  @doc """
  Converts a Lux Signal back into an outgoing Discord API payload format.
  """
  @spec to_discord_payload(Lux.Signal.t()) :: {:ok, map()} | {:error, term()}
  def to_discord_payload(%Lux.Signal{schema_id: Lux.Schemas.Discord.MessageSignalSchema, payload: p}) do
    payload = %{
      content: p.content,
      embeds: Map.get(p, :embeds, []),
      components: Map.get(p, :components, [])
    }
    {:ok, payload}
  end

  def to_discord_payload(%Lux.Signal{schema_id: Lux.Schemas.Discord.InteractionSignalSchema, payload: p}) do
    payload = %{
      type: 4, # InteractionCallbackType: ChannelMessageWithSource
      data: %{
        content: "Handled interaction #{p.name}"
      }
    }
    {:ok, payload}
  end

  def to_discord_payload(%Lux.Signal{schema_id: Lux.Schemas.Discord.PresenceSignalSchema, payload: p}) do
    payload = %{
      status: p.status,
      activities: p.activities
    }
    {:ok, payload}
  end

  def to_discord_payload(%Lux.Signal{schema_id: Lux.Schemas.Discord.VoiceSignalSchema, payload: p}) do
    payload = %{
      guild_id: p.guild_id,
      channel_id: p.channel_id,
      self_mute: p.action == "mute",
      self_deaf: p.action == "deaf"
    }
    {:ok, payload}
  end

  def to_discord_payload(other) do
    {:error, "Unrecognized Discord signal: #{inspect(other)}"}
  end

  defp parse_interaction_type(2), do: "slash_command"
  defp parse_interaction_type(3), do: "button"
  defp parse_interaction_type(5), do: "modal"
  defp parse_interaction_type(_), do: "slash_command"
end
