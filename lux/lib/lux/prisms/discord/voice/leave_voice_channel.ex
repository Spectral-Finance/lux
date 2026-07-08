defmodule Lux.Prisms.Discord.VoiceChannelLeave do
  @moduledoc """
  Leave the current voice channel in a Discord guild.
  """

  @spec leave_voice_channel(Lux.Lens.t(), binary()) :: {:ok, map} | {:error, binary()}
  def leave_voice_channel(%Lux.Lens{} = lens, guild_id) do
    url = "https://discord.com/api/v10/guilds/#{guild_id}/voice-states/@me"

    lens
    |> Lux.Lens.put(:method, :patch)
    |> Lux.Lens.put(:url, url)
    |> Lux.Lens.put(:body, %{"channel_id" => nil})
    |> Lux.Lens.execute()
  end
end
