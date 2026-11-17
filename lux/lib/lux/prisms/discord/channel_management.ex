defmodule Lux.Prisms.Discord.ChannelManagement do
  @moduledoc """
  Manages Discord channel operations and permissions.
  """
  use Lux.Prism

  @description "Handles CRUD operations for Discord channels and permission management."

  def run(%{action: :create, guild_id: guild_id, name: name, type: type} = params) do
    opts = Map.take(params, [:topic, :parent_id, :nsfw])
    DiscordClient.create_guild_channel(guild_id, name, type, opts)
  end

  def run(%{action: :update_permissions, channel_id: cid, overwrite_id: oid, allow: allow, deny: deny}) do
    DiscordClient.edit_channel_permissions(cid, oid, allow, deny)
  end

  def run(%{action: :archive, channel_id: channel_id}) do
    # Archiving in Discord is typically done by moving to an archive category or syncing permissions
    DiscordClient.edit_channel(channel_id, %{archived: true})
  end

  def run(%{action: :delete, channel_id: channel_id}) do
    DiscordClient.delete_channel(channel_id)
  end
end
