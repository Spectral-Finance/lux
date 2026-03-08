defmodule Lux.Prisms.Discord.MemberInteraction do
  @moduledoc "Agent Discord: DMs, member management, activity tracking."

  alias Lux.Integrations.Discord.Client

  def send_dm(user_id, content, opts \\ %{}) do
    with {:ok, channel} <- Client.request(:post, "/users/@me/channels", Map.merge(opts, %{json: %{recipient_id: user_id}})) do
      channel_id = channel["id"]
      Client.request(:post, "/channels/#{channel_id}/messages", Map.merge(opts, %{json: %{content: content}}))
    end
  end

  def kick_member(guild_id, user_id, opts \\ %{}) do
    Client.request(:delete, "/guilds/#{guild_id}/members/#{user_id}", opts)
  end

  def ban_member(guild_id, user_id, opts \\ %{}) do
    body = %{delete_message_days: opts[:delete_days] || 0}
    Client.request(:put, "/guilds/#{guild_id}/bans/#{user_id}", Map.merge(opts, %{json: body}))
  end

  def unban_member(guild_id, user_id, opts \\ %{}) do
    Client.request(:delete, "/guilds/#{guild_id}/bans/#{user_id}", opts)
  end

  def get_member(guild_id, user_id, opts \\ %{}) do
    Client.request(:get, "/guilds/#{guild_id}/members/#{user_id}", opts)
  end

  def nickname(guild_id, user_id, nick, opts \\ %{}) do
    Client.request(:patch, "/guilds/#{guild_id}/members/#{user_id}", Map.merge(opts, %{json: %{nick: nick}}))
  end
end
