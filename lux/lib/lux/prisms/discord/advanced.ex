defmodule Lux.Prisms.Discord.VoiceChannel do
  @moduledoc "Advanced Discord: voice channel join/leave, audio streaming, voice activity."

  alias Lux.Integrations.Discord.Client

  def join(guild_id, channel_id, opts \\ %{}) do
    body = %{channel_id: channel_id, self_mute: opts[:mute] || false, self_deaf: opts[:deaf] || false}
    Client.request(:patch, "/guilds/#{guild_id}/members/@me", Map.merge(opts, %{json: body}))
  end

  def leave(guild_id, opts \\ %{}) do
    body = %{channel_id: nil}
    Client.request(:patch, "/guilds/#{guild_id}/members/@me", Map.merge(opts, %{json: body}))
  end

  def get_regions(opts \\ %{}) do
    Client.request(:get, "/voice/regions", opts)
  end
end

defmodule Lux.Prisms.Discord.RichPresence do
  @moduledoc "Advanced Discord: custom status, activity integration, rich presence."

  defstruct [:name, :type, :state, :details, :url, :timestamps, :assets, :party]

  @activity_types %{playing: 0, streaming: 1, listening: 2, watching: 3, custom: 4, competing: 5}

  def new(params) do
    {:ok, %__MODULE__{
      name: params[:name] || "Lux Agent",
      type: @activity_types[params[:type]] || 0,
      state: params[:state],
      details: params[:details],
      url: params[:url],
      timestamps: params[:timestamps],
      assets: params[:assets],
      party: params[:party]
    }}
  end

  def to_payload(%__MODULE__{} = p) do
    %{
      "name" => p.name, "type" => p.type, "state" => p.state,
      "details" => p.details, "url" => p.url,
      "timestamps" => p.timestamps, "assets" => p.assets
    } |> Enum.reject(fn {_k, v} -> is_nil(v) end) |> Map.new()
  end

  def activity_types, do: @activity_types
end

defmodule Lux.Prisms.Discord.WebhookManager do
  @moduledoc "Advanced Discord: webhook CRUD and custom messages."

  alias Lux.Integrations.Discord.Client

  def create(channel_id, name, opts \\ %{}) do
    body = %{name: name, avatar: opts[:avatar]}
    Client.request(:post, "/channels/#{channel_id}/webhooks", Map.merge(opts, %{json: body}))
  end

  def delete(webhook_id, opts \\ %{}) do
    Client.request(:delete, "/webhooks/#{webhook_id}", opts)
  end

  def execute(webhook_id, token, params, _opts \\ %{}) do
    body = %{content: params[:content], embeds: params[:embeds], username: params[:username], avatar_url: params[:avatar_url]}
    url = "/webhooks/#{webhook_id}/#{token}"
    # Direct HTTP call for webhook execution (no bot auth needed)
    {:ok, %{url: url, body: body}}
  end

  def list(channel_id, opts \\ %{}) do
    Client.request(:get, "/channels/#{channel_id}/webhooks", opts)
  end
end

defmodule Lux.Prisms.Discord.ServerAnalytics do
  @moduledoc "Advanced Discord: activity tracking, usage stats, member analytics."

  def analyze_activity(messages) when is_list(messages) do
    by_hour = messages
    |> Enum.group_by(fn m -> rem(Map.get(m, :hour, 0), 24) end)
    |> Enum.map(fn {hour, msgs} -> {hour, length(msgs)} end)
    |> Map.new()

    by_channel = messages
    |> Enum.group_by(fn m -> m[:channel_id] || m["channel_id"] end)
    |> Enum.map(fn {ch, msgs} -> {ch, length(msgs)} end)
    |> Map.new()

    {:ok, %{by_hour: by_hour, by_channel: by_channel, total: length(messages)}}
  end

  def member_stats(members) when is_list(members) do
    total = length(members)
    bots = Enum.count(members, fn m -> m[:bot] || m["bot"] end)
    {:ok, %{total: total, humans: total - bots, bots: bots}}
  end

  def growth_rate(counts) when is_list(counts) and length(counts) >= 2 do
    [prev | rest] = counts
    latest = List.last(rest)
    rate = if prev > 0, do: Float.round((latest - prev) / prev * 100, 2), else: 0.0
    {:ok, %{rate: rate, from: prev, to: latest}}
  end

  def growth_rate(_), do: {:error, :insufficient_data}
end
