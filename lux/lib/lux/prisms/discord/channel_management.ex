defmodule Lux.Prisms.Discord.ChannelManagement do
  @moduledoc """
  Channel management prism: CRUD, permissions, archiving.
  """

  alias Lux.Integrations.Discord.Client

  @channel_types %{text: 0, voice: 2, category: 4, announcement: 5, forum: 15, stage: 13}

  @doc "Create a channel in a guild."
  def create_channel(guild_id, params, opts \\ %{}) do
    body = %{
      name: params[:name],
      type: Map.get(@channel_types, params[:type] || :text, 0)
    }
    |> maybe_put(:topic, params[:topic])
    |> maybe_put(:parent_id, params[:parent_id])
    |> maybe_put(:position, params[:position])
    |> maybe_put(:nsfw, params[:nsfw])
    |> maybe_put(:rate_limit_per_user, params[:slowmode])

    Client.request(:post, "/guilds/#{guild_id}/channels", Map.merge(opts, %{json: body}))
  end

  @doc "Edit a channel."
  def edit_channel(channel_id, params, opts \\ %{}) do
    body = %{}
    |> maybe_put(:name, params[:name])
    |> maybe_put(:topic, params[:topic])
    |> maybe_put(:position, params[:position])
    |> maybe_put(:nsfw, params[:nsfw])
    |> maybe_put(:rate_limit_per_user, params[:slowmode])
    |> maybe_put(:parent_id, params[:parent_id])

    Client.request(:patch, "/channels/#{channel_id}", Map.merge(opts, %{json: body}))
  end

  @doc "Delete a channel."
  def delete_channel(channel_id, opts \\ %{}) do
    Client.request(:delete, "/channels/#{channel_id}", opts)
  end

  @doc "Get channel info."
  def get_channel(channel_id, opts \\ %{}) do
    Client.request(:get, "/channels/#{channel_id}", opts)
  end

  @doc "Set permission overwrite for a channel."
  def set_permission(channel_id, overwrite_id, params, opts \\ %{}) do
    body = %{
      id: overwrite_id,
      type: params[:type] || 0,
      allow: to_string(params[:allow] || 0),
      deny: to_string(params[:deny] || 0)
    }
    Client.request(:put, "/channels/#{channel_id}/permissions/#{overwrite_id}", Map.merge(opts, %{json: body}))
  end

  @doc "Archive a channel (set archived flag for threads/forums)."
  def archive_channel(channel_id, opts \\ %{}) do
    Client.request(:patch, "/channels/#{channel_id}", Map.merge(opts, %{json: %{archived: true}}))
  end

  @doc "Unarchive a channel."
  def unarchive_channel(channel_id, opts \\ %{}) do
    Client.request(:patch, "/channels/#{channel_id}", Map.merge(opts, %{json: %{archived: false}}))
  end

  @doc "List guild channels."
  def list_channels(guild_id, opts \\ %{}) do
    Client.request(:get, "/guilds/#{guild_id}/channels", opts)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
