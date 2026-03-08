defmodule Lux.Prisms.Twitter.Analytics.MetricsCollector do
  @moduledoc """
  Collects and stores Twitter engagement metrics in real-time.

  Tracks:
  - Tweet engagement (likes, retweets, replies, quotes, impressions)
  - Follower growth over time
  - Hashtag performance
  - Mention frequency
  """

  use GenServer

  defstruct [:tweets, :follower_snapshots, :hashtags, :mentions, :custom_metrics]

  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def track_tweet(pid \\ __MODULE__, tweet) do
    GenServer.cast(pid, {:track_tweet, tweet})
  end

  def track_follower_count(pid \\ __MODULE__, count) do
    GenServer.cast(pid, {:track_follower_count, count})
  end

  def track_mention(pid \\ __MODULE__, mention) do
    GenServer.cast(pid, {:track_mention, mention})
  end

  def define_metric(pid \\ __MODULE__, name, calculator) do
    GenServer.call(pid, {:define_metric, name, calculator})
  end

  def get_tweet_metrics(pid \\ __MODULE__, tweet_id) do
    GenServer.call(pid, {:get_tweet_metrics, tweet_id})
  end

  def get_overview(pid \\ __MODULE__) do
    GenServer.call(pid, :get_overview)
  end

  def get_follower_history(pid \\ __MODULE__) do
    GenServer.call(pid, :get_follower_history)
  end

  def get_top_tweets(pid \\ __MODULE__, opts \\ %{}) do
    GenServer.call(pid, {:get_top_tweets, opts})
  end

  def get_hashtag_stats(pid \\ __MODULE__) do
    GenServer.call(pid, :get_hashtag_stats)
  end

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{
      tweets: %{},
      follower_snapshots: [],
      hashtags: %{},
      mentions: [],
      custom_metrics: %{}
    }}
  end

  @impl true
  def handle_cast({:track_tweet, tweet}, state) do
    id = tweet[:id]
    entry = %{
      id: id,
      text: tweet[:text],
      likes: tweet[:likes] || 0,
      retweets: tweet[:retweets] || 0,
      replies: tweet[:replies] || 0,
      quotes: tweet[:quotes] || 0,
      impressions: tweet[:impressions] || 0,
      hashtags: extract_hashtags(tweet[:text] || ""),
      tracked_at: DateTime.utc_now()
    }

    # Update hashtag counters
    hashtags = Enum.reduce(entry.hashtags, state.hashtags, fn tag, acc ->
      Map.update(acc, tag, %{count: 1, total_engagement: engagement_score(entry)},
        fn existing -> %{existing | count: existing.count + 1, total_engagement: existing.total_engagement + engagement_score(entry)} end)
    end)

    {:noreply, %{state | tweets: Map.put(state.tweets, id, entry), hashtags: hashtags}}
  end

  @impl true
  def handle_cast({:track_follower_count, count}, state) do
    snapshot = %{count: count, at: DateTime.utc_now()}
    {:noreply, %{state | follower_snapshots: [snapshot | state.follower_snapshots]}}
  end

  @impl true
  def handle_cast({:track_mention, mention}, state) do
    entry = Map.merge(mention, %{at: DateTime.utc_now()})
    {:noreply, %{state | mentions: [entry | Enum.take(state.mentions, 9999)]}}
  end

  @impl true
  def handle_call({:define_metric, name, calculator}, _from, state) do
    {:reply, :ok, %{state | custom_metrics: Map.put(state.custom_metrics, name, calculator)}}
  end

  @impl true
  def handle_call({:get_tweet_metrics, tweet_id}, _from, state) do
    case Map.get(state.tweets, tweet_id) do
      nil -> {:reply, {:error, :not_found}, state}
      tweet -> {:reply, {:ok, Map.put(tweet, :engagement_score, engagement_score(tweet))}, state}
    end
  end

  @impl true
  def handle_call(:get_overview, _from, state) do
    tweets = Map.values(state.tweets)
    total_engagement = Enum.sum(Enum.map(tweets, &engagement_score/1))
    {:reply, {:ok, %{
      total_tweets: length(tweets),
      total_engagement: total_engagement,
      avg_engagement: if(length(tweets) > 0, do: Float.round(total_engagement / length(tweets), 2), else: 0.0),
      total_impressions: Enum.sum(Enum.map(tweets, & &1.impressions)),
      total_mentions: length(state.mentions),
      follower_count: case state.follower_snapshots do
        [latest | _] -> latest.count
        [] -> 0
      end,
      follower_change: follower_change(state.follower_snapshots)
    }}, state}
  end

  @impl true
  def handle_call(:get_follower_history, _from, state) do
    {:reply, {:ok, Enum.reverse(state.follower_snapshots)}, state}
  end

  @impl true
  def handle_call({:get_top_tweets, opts}, _from, state) do
    sort_by = opts[:sort_by] || :engagement
    limit = opts[:limit] || 10

    sorted = Map.values(state.tweets)
    |> Enum.sort_by(fn t ->
      case sort_by do
        :engagement -> engagement_score(t)
        :likes -> t.likes
        :retweets -> t.retweets
        :impressions -> t.impressions
        _ -> engagement_score(t)
      end
    end, :desc)
    |> Enum.take(limit)

    {:reply, {:ok, sorted}, state}
  end

  @impl true
  def handle_call(:get_hashtag_stats, _from, state) do
    sorted = state.hashtags
    |> Enum.sort_by(fn {_, v} -> v.total_engagement end, :desc)
    {:reply, {:ok, sorted}, state}
  end

  defp engagement_score(tweet) do
    (tweet[:likes] || tweet.likes || 0) +
    (tweet[:retweets] || tweet.retweets || 0) * 2 +
    (tweet[:replies] || tweet.replies || 0) * 3 +
    (tweet[:quotes] || tweet.quotes || 0) * 4
  end

  defp extract_hashtags(text) do
    Regex.scan(~r/#(\w+)/, text) |> Enum.map(fn [_, tag] -> String.downcase(tag) end)
  end

  defp follower_change([latest, previous | _]) do
    latest.count - previous.count
  end
  defp follower_change(_), do: 0
end
