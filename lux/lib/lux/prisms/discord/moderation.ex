defmodule Lux.Prisms.Discord.Moderation do
  @moduledoc """
  Handles server moderation tasks such as bans, timeouts, and warnings.
  """
  use Lux.Prism

  @description "Provides moderation tools for user management and content filtering."

  def run(%{action: :ban, guild_id: gid, user_id: uid, reason: reason}) do
    DiscordClient.create_guild_ban(gid, uid, reason: reason)
  end

  def run(%{action: :timeout, guild_id: gid, user_id: uid, duration_minutes: minutes}) do
    until = DateTime.utc_now() |> DateTime.add(minutes, :minute)
    DiscordClient.edit_guild_member(gid, uid, communication_disabled_until: until)
  end

  def run(%{action: :warn, guild_id: gid, user_id: uid, reason: reason}) do
    # Warnings are often stored in a local DB as Discord doesn't have a native 'warn' object
    with {:ok, _} <- Lux.Store.append("warnings:#{gid}:#{uid}", %{reason: reason, timestamp: DateTime.utc_now()}) do
      {:ok, %{status: "warning_recorded", user_id: uid}}
    end
  end

  def run(%{action: :unban, guild_id: gid, user_id: uid}) do
    DiscordClient.remove_guild_ban(gid, uid)
  end
end
