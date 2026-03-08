defmodule Lux.Prisms.Discord.ServerManagement do
  @moduledoc "Agent Discord: server join/leave, channel/role CRUD, activity monitoring."

  alias Lux.Integrations.Discord.Client

  def join_server(invite_code, opts \\ %{}) do
    Client.request(:post, "/invites/#{invite_code}", opts)
  end

  def leave_server(guild_id, opts \\ %{}) do
    Client.request(:delete, "/users/@me/guilds/#{guild_id}", opts)
  end

  def create_channel(guild_id, params, opts \\ %{}) do
    body = %{name: params[:name], type: params[:type] || 0, parent_id: params[:parent_id]}
    Client.request(:post, "/guilds/#{guild_id}/channels", Map.merge(opts, %{json: body}))
  end

  def delete_channel(channel_id, opts \\ %{}) do
    Client.request(:delete, "/channels/#{channel_id}", opts)
  end

  def create_role(guild_id, params, opts \\ %{}) do
    body = %{name: params[:name], permissions: params[:permissions] || "0", color: params[:color] || 0}
    Client.request(:post, "/guilds/#{guild_id}/roles", Map.merge(opts, %{json: body}))
  end

  def assign_role(guild_id, user_id, role_id, opts \\ %{}) do
    Client.request(:put, "/guilds/#{guild_id}/members/#{user_id}/roles/#{role_id}", opts)
  end

  def remove_role(guild_id, user_id, role_id, opts \\ %{}) do
    Client.request(:delete, "/guilds/#{guild_id}/members/#{user_id}/roles/#{role_id}", opts)
  end

  def list_members(guild_id, opts \\ %{}) do
    Client.request(:get, "/guilds/#{guild_id}/members?limit=#{opts[:limit] || 100}", opts)
  end
end
