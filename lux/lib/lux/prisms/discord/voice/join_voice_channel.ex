defmodule Lux.Prisms.Discord.VoiceChannelJoin do
  @moduledoc """
  Join a voice channel in a Discord guild.

  Uses the Discord API to join a specified voice channel.
  Requires bot to have Connect permission in the channel.
  """

  @spec join_voice_channel(Lux.Lens.t(), binary(), binary()) :: {:ok, map} | {:error, binary()}
  def join_voice_channel(%Lux.Lens{} = lens, guild_id, channel_id) do
    url = "https://discord.com/api/v10/guilds/#{guild_id}/voice-states/@me"

    lens
    |> Lux.Lens.put(:method, :patch)
    |> Lux.Lens.put(:url, url)
    |> Lux.Lens.put(:body, %{"channel_id" => channel_id})
    |> Lux.Lens.execute()
  end
end
