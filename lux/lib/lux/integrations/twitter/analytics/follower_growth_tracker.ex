defmodule Lux.Integrations.Twitter.Analytics.FollowerGrowthTracker do
  @moduledoc """
  Tracks and analyzes follower growth trajectories and account statistics over time.
  Calculates net follower changes, percentage growth rate, follower-to-following ratios,
  and projected trajectory metrics.
  """

  @type snapshot :: %{
          timestamp: String.t(),
          followers_count: non_neg_integer(),
          following_count: non_neg_integer(),
          tweet_count: non_neg_integer()
        }

  @type growth_analysis :: %{
          net_follower_change: integer(),
          growth_rate_percent: float(),
          follower_to_following_ratio: float(),
          daily_run_rate: float(),
          current_followers: non_neg_integer(),
          snapshot_count: non_neg_integer()
        }

  @doc """
  Analyzes historical follower snapshots to determine growth velocity.
  """
  @spec analyze_growth(list(snapshot())) :: growth_analysis()
  def analyze_growth([]) do
    %{
      net_follower_change: 0,
      growth_rate_percent: 0.0,
      follower_to_following_ratio: 0.0,
      daily_run_rate: 0.0,
      current_followers: 0,
      snapshot_count: 0
    }
  end

  def analyze_growth([single]) do
    followers = Map.get(single, :followers_count, Map.get(single, "followers_count", 0))
    following = Map.get(single, :following_count, Map.get(single, "following_count", 1))

    ratio = if following > 0, do: Float.round(followers / following, 2), else: 0.0

    %{
      net_follower_change: 0,
      growth_rate_percent: 0.0,
      follower_to_following_ratio: ratio,
      daily_run_rate: 0.0,
      current_followers: followers,
      snapshot_count: 1
    }
  end

  def analyze_growth(snapshots) when is_list(snapshots) do
    # Sort chronologically by timestamp
    sorted =
      Enum.sort_by(snapshots, fn s ->
        ts = Map.get(s, :timestamp, Map.get(s, "timestamp", ""))
        case DateTime.from_iso8601(ts) do
          {:ok, dt, _} -> DateTime.to_unix(dt)
          _ -> 0
        end
      end)

    oldest = hd(sorted)
    latest = List.last(sorted)

    old_followers = Map.get(oldest, :followers_count, Map.get(oldest, "followers_count", 0))
    new_followers = Map.get(latest, :followers_count, Map.get(latest, "followers_count", 0))
    new_following = Map.get(latest, :following_count, Map.get(latest, "following_count", 1))

    net_change = new_followers - old_followers

    growth_pct =
      if old_followers > 0 do
        Float.round((net_change / old_followers) * 100.0, 2)
      else
        0.0
      end

    ratio = if new_following > 0, do: Float.round(new_followers / new_following, 2), else: 0.0

    # Calculate daily velocity if time delta > 0
    old_time = parse_timestamp(Map.get(oldest, :timestamp, Map.get(oldest, "timestamp")))
    new_time = parse_timestamp(Map.get(latest, :timestamp, Map.get(latest, "timestamp")))
    days = max((new_time - old_time) / 86400.0, 0.01)
    daily_run_rate = Float.round(net_change / days, 2)

    %{
      net_follower_change: net_change,
      growth_rate_percent: growth_pct,
      follower_to_following_ratio: ratio,
      daily_run_rate: daily_run_rate,
      current_followers: new_followers,
      snapshot_count: length(snapshots)
    }
  end

  defp parse_timestamp(nil), do: 0
  defp parse_timestamp(ts) when is_binary(ts) do
    case DateTime.from_iso8601(ts) do
      {:ok, dt, _} -> DateTime.to_unix(dt)
      _ -> 0
    end
  end
  defp parse_timestamp(unix) when is_integer(unix), do: unix
end
