defmodule Lux.Integrations.Discord.Analytics do
  @moduledoc """
  Discord Server Analytics via REST API.

  Provides real Discord API calls for audit logs, guild members, guild info,
  and local computation for activity tracking, usage statistics, and member analytics.

  ## REST API Operations

    * `get_audit_log/2` - Fetch guild audit log entries
    * `get_guild_members/2` - Fetch guild member list
    * `get_guild/2` - Fetch guild information
    * `get_guild_channels/2` - Fetch guild channels

  ## Local Analytics

    * `analyze_activity/1` - Compute activity metrics from event data
    * `member_stats/1` - Compute member statistics from member list
    * `channel_usage/1` - Compute channel usage from message events

  Requires the bot to have appropriate permissions:
    * `VIEW_AUDIT_LOG` for audit logs
    * `GUILD_MEMBERS` privileged intent for member listing
  """

  alias Lux.Integrations.Discord.Client

  @type request_opts :: keyword() | map()
  @type event :: %{
          type: atom(),
          user_id: String.t(),
          channel_id: String.t() | nil,
          timestamp: DateTime.t() | nil,
          metadata: map()
        }

  # --- REST API ---

  @doc """
  Fetches the audit log for a guild.

  ## Options

    * `:user_id` - Filter by user ID
    * `:action_type` - Filter by action type integer (see Discord docs)
    * `:before` - Entry ID to fetch before
    * `:limit` - Max entries (1-100, default 50)

  ## Examples

      {:ok, log} = Analytics.get_audit_log("guild_id", limit: 10)
      %{"audit_log_entries" => [...], "users" => [...], "integrations" => [...]}

  """
  @spec get_audit_log(String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def get_audit_log(guild_id, opts \\ %{}) do
    params = build_query_params(opts, [:user_id, :action_type, :before, :limit])
    path = "/guilds/#{guild_id}/audit-logs" <> encode_query(params)

    case Client.request(:get, path, Map.drop(opts, [:user_id, :action_type, :before, :limit])) do
      {:ok, result} -> {:ok, result}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Fetches members of a guild.

  ## Options

    * `:limit` - Max members (1-1000, default 1)
    * `:after` - Member ID to fetch after (for pagination)

  ## Examples

      {:ok, members} = Analytics.get_guild_members("guild_id", limit: 100)

  """
  @spec get_guild_members(String.t(), request_opts()) :: {:ok, [map()]} | {:error, term()}
  def get_guild_members(guild_id, opts \\ %{}) do
    params = build_query_params(opts, [:limit, :after])
    path = "/guilds/#{guild_id}/members" <> encode_query(params)

    case Client.request(:get, path, Map.drop(opts, [:limit, :after])) do
      {:ok, members} when is_list(members) -> {:ok, members}
      {:ok, other} -> {:error, {:unexpected_response, other}}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Fetches guild information.

  ## Examples

      {:ok, guild} = Analytics.get_guild("guild_id")
      %{"id" => "...", "name" => "...", "member_count" => 1234, ...}

  """
  @spec get_guild(String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def get_guild(guild_id, opts \\ %{}) do
    case Client.request(:get, "/guilds/#{guild_id}?with_counts=true", opts) do
      {:ok, guild} -> {:ok, guild}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Fetches channels in a guild.

  ## Examples

      {:ok, channels} = Analytics.get_guild_channels("guild_id")

  """
  @spec get_guild_channels(String.t(), request_opts()) :: {:ok, [map()]} | {:error, term()}
  def get_guild_channels(guild_id, opts \\ %{}) do
    case Client.request(:get, "/guilds/#{guild_id}/channels", opts) do
      {:ok, channels} when is_list(channels) -> {:ok, channels}
      {:ok, other} -> {:error, {:unexpected_response, other}}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Fetches a ban list for a guild.

  ## Options

    * `:limit` - Max bans (1-1000)
    * `:before` - User ID to fetch before
    * `:after` - User ID to fetch after

  """
  @spec get_guild_bans(String.t(), request_opts()) :: {:ok, [map()]} | {:error, term()}
  def get_guild_bans(guild_id, opts \\ %{}) do
    params = build_query_params(opts, [:limit, :before, :after])
    path = "/guilds/#{guild_id}/bans" <> encode_query(params)

    case Client.request(:get, path, Map.drop(opts, [:limit, :before, :after])) do
      {:ok, bans} when is_list(bans) -> {:ok, bans}
      {:ok, other} -> {:error, {:unexpected_response, other}}
      {:error, error} -> {:error, error}
    end
  end

  # --- Local Analytics ---

  @doc """
  Computes activity metrics from a list of events.

  ## Input

  A list of event maps with at least `:type`, `:user_id`, `:channel_id`, and `:timestamp` keys.

  ## Output

      %{
        total_events: 100,
        by_type: %{message: 80, voice: 15, webhook: 5},
        by_hour: %{0 => 5, 1 => 3, ...},
        by_user: %{"user1" => 40, "user2" => 35, ...},
        by_channel: %{"ch1" => 60, "ch2" => 40, ...},
        peak_hour: 14,
        most_active_user: "user1",
        most_active_channel: "ch1"
      }

  """
  @spec analyze_activity([event()]) :: map()
  def analyze_activity(events) when is_list(events) do
    by_type = Enum.group_by(events, & &1.type) |> Map.new(fn {k, v} -> {k, length(v)} end)
    by_user = Enum.group_by(events, & &1.user_id) |> Map.new(fn {k, v} -> {k, length(v)} end)
    by_channel = events |> Enum.reject(&is_nil(&1.channel_id)) |> Enum.group_by(& &1.channel_id) |> Map.new(fn {k, v} -> {k, length(v)} end)
    by_hour = events |> Enum.reject(&is_nil(&1.timestamp)) |> Enum.group_by(& &1.timestamp.hour) |> Map.new(fn {k, v} -> {k, length(v)} end)

    %{
      total_events: length(events),
      by_type: by_type,
      by_hour: by_hour,
      by_user: by_user,
      by_channel: by_channel,
      peak_hour: max_key(by_hour),
      most_active_user: max_key(by_user),
      most_active_channel: max_key(by_channel)
    }
  end

  @doc """
  Computes member statistics from a guild member list.

  ## Output

      %{
        total: 1234,
        humans: 1200,
        bots: 34,
        bot_ratio: 0.028,
        roles_distribution: %{"admin" => 5, "member" => 1200, ...},
        online_estimate: nil  # requires presence intent
      }

  """
  @spec member_stats([map()]) :: map()
  def member_stats(members) when is_list(members) do
    {humans, bots} = Enum.split_with(members, &(get_in(&1, ["user", "bot"]) != true))

    roles_distribution =
      members
      |> Enum.flat_map(fn m -> Map.get(m, "roles", []) end)
      |> Enum.frequencies()

    %{
      total: length(members),
      humans: length(humans),
      bots: length(bots),
      bot_ratio: safe_ratio(length(bots), length(members)),
      roles_distribution: roles_distribution
    }
  end

  @doc """
  Computes channel usage statistics from message events.

  ## Input

  A list of event maps with `:channel_id`, `:user_id`, and `:timestamp`.

  ## Output

      %{
        total_messages: 100,
        channels: %{
          "ch1" => %{
            count: 60,
            unique_users: 5,
            most_active_user: "user1",
            hourly_distribution: %{14 => 10, 15 => 8, ...}
          }
        }
      }

  """
  @spec channel_usage([event()]) :: map()
  def channel_usage(events) when is_list(events) do
    message_events = Enum.filter(events, &(&1.type == :message))
    by_channel = Enum.group_by(message_events, & &1.channel_id)

    channels =
      Map.new(by_channel, fn {channel_id, channel_events} ->
        by_user = Enum.group_by(channel_events, & &1.user_id) |> Map.new(fn {k, v} -> {k, length(v)} end)
        by_hour = channel_events |> Enum.reject(&is_nil(&1.timestamp)) |> Enum.group_by(& &1.timestamp.hour) |> Map.new(fn {k, v} -> {k, length(v)} end)

        {channel_id,
         %{
           count: length(channel_events),
           unique_users: map_size(by_user),
           most_active_user: max_key(by_user),
           hourly_distribution: by_hour
         }}
      end)

    %{
      total_messages: length(message_events),
      channels: channels
    }
  end

  @doc """
  Computes voice channel activity from voice events.

  ## Output

      %{
        total_voice_events: 15,
        join_count: 8,
        leave_count: 7,
        average_session_minutes: 45.0,
        unique_users: 5,
        channels: %{
          "vc1" => %{joins: 5, leaves: 4, unique_users: 3}
        }
      }

  """
  @spec voice_analytics([event()]) :: map()
  def voice_analytics(events) when is_list(events) do
    voice_events = Enum.filter(events, &(&1.type == :voice))
    joins = Enum.filter(voice_events, &(get_in(&1, [:metadata, :action]) == :join))
    leaves = Enum.filter(voice_events, &(get_in(&1, [:metadata, :action]) == :leave))

    by_channel =
      voice_events
      |> Enum.reject(&is_nil(&1.channel_id))
      |> Enum.group_by(& &1.channel_id)
      |> Map.new(fn {ch_id, evts} ->
        ch_joins = Enum.filter(evts, &(get_in(&1, [:metadata, :action]) == :join))
        ch_leaves = Enum.filter(evts, &(get_in(&1, [:metadata, :action]) == :leave))
        unique = evts |> Enum.map(& &1.user_id) |> Enum.uniq() |> length()

        {ch_id,
         %{
           joins: length(ch_joins),
           leaves: length(ch_leaves),
           unique_users: unique
         }}
      end)

    unique_users = voice_events |> Enum.map(& &1.user_id) |> Enum.uniq() |> length()

    %{
      total_voice_events: length(voice_events),
      join_count: length(joins),
      leave_count: length(leaves),
      unique_users: unique_users,
      channels: by_channel
    }
  end

  # --- Private Helpers ---

  defp max_key(map) when map_size(map) == 0, do: nil
  defp max_key(map) do
    {key, _} = Enum.max_by(map, fn {_, v} -> v end)
    key
  end

  defp safe_ratio(_, 0), do: 0.0
  defp safe_ratio(a, b), do: a / b

  defp build_query_params(opts, keys) do
    keys
    |> Enum.flat_map(fn key ->
      case get_opt(opts, key) do
        nil -> []
        val -> [{key, val}]
      end
    end)
  end

  defp encode_query([]), do: ""
  defp encode_query(params) do
    "?" <> URI.encode_query(Enum.map(params, fn {k, v} -> {to_string(k), to_string(v)} end))
  end

  defp get_opt(opts, key) when is_map(opts), do: Map.get(opts, key)
  defp get_opt(opts, key) when is_list(opts), do: Keyword.get(opts, key)
end
