defmodule Lux.TwitterAnalytics.MetricsCollector do
  @moduledoc """
  GenServer for collecting real-time Twitter metrics using Lux Twitter lenses.

  Supports monitoring:
  - Individual tweets
  - User activity
  - Hashtag performance

  Integrates with GetTweet, GetUserTweets, and GetUser lenses.
  """
  use GenServer
  require Logger

  alias Lux.TwitterAnalytics.{Aggregator, SentimentAnalyzer}
  alias Lux.Lenses.Twitter.{GetTweet, GetUserTweets}

  @default_interval 5 * 60 * 1000  # 5 minutes
  @max_requests_per_window 900      # Twitter API limit: 900 requests per 15 min
  @window_duration 15 * 60 * 1000   # 15 minutes

  ## Client API

  @doc """
  Start the MetricsCollector GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Start monitoring a specific tweet.
  """
  def start_monitoring(tweet_id, opts \\ []) do
    GenServer.call(__MODULE__, {:start_monitoring, :tweet, tweet_id, opts})
  end

  @doc """
  Start monitoring a user's activity.
  """
  def start_user_monitoring(user_id, opts \\ []) do
    GenServer.call(__MODULE__, {:start_monitoring, :user, user_id, opts})
  end

  @doc """
  Start monitoring a hashtag.
  """
  def start_hashtag_monitoring(hashtag, opts \\ []) do
    GenServer.call(__MODULE__, {:start_monitoring, :hashtag, hashtag, opts})
  end

  @doc """
  Stop monitoring a target.
  """
  def stop_monitoring(monitor_id) do
    GenServer.call(__MODULE__, {:stop_monitoring, monitor_id})
  end

  @doc """
  Force immediate collection for a specific monitor.
  """
  def collect_now(monitor_id) do
    GenServer.cast(__MODULE__, {:collect_now, monitor_id})
  end

  @doc """
  List all active monitors.
  """
  def list_monitors do
    GenServer.call(__MODULE__, :list_monitors)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting TwitterAnalytics.MetricsCollector")

    state = %{
      monitors: %{},
      rate_limit: %{
        requests: 0,
        window_start: System.monotonic_time(:millisecond)
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:start_monitoring, type, target, opts}, _from, state) do
    monitor_id = generate_monitor_id(type, target)
    interval = Keyword.get(opts, :interval, @default_interval)

    monitor = %{
      id: monitor_id,
      type: type,
      target: target,
      interval: interval,
      last_collected: nil,
      options: opts
    }

    # Schedule first collection
    schedule_collection(monitor_id, 0)

    new_state = put_in(state.monitors[monitor_id], monitor)
    {:reply, {:ok, monitor_id}, new_state}
  end

  @impl true
  def handle_call({:stop_monitoring, monitor_id}, _from, state) do
    new_state = %{state | monitors: Map.delete(state.monitors, monitor_id)}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:list_monitors, _from, state) do
    {:reply, {:ok, Map.values(state.monitors)}, state}
  end

  @impl true
  def handle_cast({:collect_now, monitor_id}, state) do
    case Map.get(state.monitors, monitor_id) do
      nil ->
        Logger.warning("Monitor #{monitor_id} not found")
        {:noreply, state}

      monitor ->
        new_state = perform_collection(monitor, state)
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:collect, monitor_id}, state) do
    case Map.get(state.monitors, monitor_id) do
      nil ->
        # Monitor was removed
        {:noreply, state}

      monitor ->
        new_state = perform_collection(monitor, state)
        # Schedule next collection
        schedule_collection(monitor_id, monitor.interval)
        {:noreply, new_state}
    end
  end

  ## Private Functions

  defp generate_monitor_id(type, target) do
    "#{type}_#{target}_#{:erlang.unique_integer([:positive])}"
  end

  defp schedule_collection(monitor_id, delay) do
    Process.send_after(self(), {:collect, monitor_id}, delay)
  end

  defp perform_collection(%{type: :tweet, target: tweet_id} = monitor, state) do
    Logger.debug("Collecting metrics for tweet: #{tweet_id}")

    case check_rate_limit(state) do
      {:ok, new_rate_limit} ->
        case collect_tweet_metrics(tweet_id) do
          {:ok, metric} ->
            Aggregator.record_metric(metric)

            # Update last_collected timestamp
            updated_monitor = %{monitor | last_collected: DateTime.utc_now()}
            new_monitors = Map.put(state.monitors, monitor.id, updated_monitor)

            %{state | monitors: new_monitors, rate_limit: new_rate_limit}

          {:error, reason} ->
            Logger.error("Failed to collect tweet metrics: #{inspect(reason)}")
            state
        end

      {:error, :rate_limited} ->
        Logger.warning("Rate limited, skipping collection for #{monitor.id}")
        state
    end
  end

  defp perform_collection(%{type: :user, target: user_id} = monitor, state) do
    Logger.debug("Collecting metrics for user: #{user_id}")

    case check_rate_limit(state) do
      {:ok, new_rate_limit} ->
        case collect_user_metrics(user_id) do
          {:ok, metrics} ->
            Enum.each(metrics, &Aggregator.record_metric/1)

            updated_monitor = %{monitor | last_collected: DateTime.utc_now()}
            new_monitors = Map.put(state.monitors, monitor.id, updated_monitor)

            %{state | monitors: new_monitors, rate_limit: new_rate_limit}

          {:error, reason} ->
            Logger.error("Failed to collect user metrics: #{inspect(reason)}")
            state
        end

      {:error, :rate_limited} ->
        Logger.warning("Rate limited, skipping collection for #{monitor.id}")
        state
    end
  end

  defp perform_collection(%{type: :hashtag} = monitor, state) do
    # Hashtag monitoring requires search API which we don't have a lens for yet
    # For MVP, we can track hashtags found in user tweets
    Logger.debug("Hashtag monitoring not yet implemented for: #{monitor.target}")
    state
  end

  defp collect_tweet_metrics(tweet_id) do
    case GetTweet.focus(%{
           id: tweet_id,
           "tweet.fields" => "public_metrics,created_at,author_id,text,entities"
         }) do
      {:ok, response} ->
        metric = %{
          tweet_id: response[:id],
          user_id: response[:author_id],
          timestamp: DateTime.utc_now(),
          metrics: %{
            likes: get_in(response, [:public_metrics, :like_count]) || 0,
            retweets: get_in(response, [:public_metrics, :retweet_count]) || 0,
            replies: get_in(response, [:public_metrics, :reply_count]) || 0,
            quotes: get_in(response, [:public_metrics, :quote_count]) || 0
          },
          sentiment: analyze_sentiment(response[:text]),
          hashtags: extract_hashtags(response),
          metadata: %{
            created_at: response[:created_at]
          }
        }

        {:ok, metric}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp collect_user_metrics(user_id) do
    case GetUserTweets.focus(%{id: user_id, max_results: 10}) do
      {:ok, response} ->
        tweets = response[:tweets] || []

        metrics =
          Enum.map(tweets, fn tweet ->
            %{
              tweet_id: tweet["id"],
              user_id: user_id,
              timestamp: DateTime.utc_now(),
              metrics: %{
                likes: get_in(tweet, ["public_metrics", "like_count"]) || 0,
                retweets: get_in(tweet, ["public_metrics", "retweet_count"]) || 0,
                replies: get_in(tweet, ["public_metrics", "reply_count"]) || 0,
                quotes: get_in(tweet, ["public_metrics", "quote_count"]) || 0
              },
              sentiment: analyze_sentiment(tweet["text"]),
              hashtags: extract_hashtags_from_text(tweet["text"]),
              metadata: %{
                created_at: tweet["created_at"]
              }
            }
          end)

        {:ok, metrics}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp analyze_sentiment(nil), do: nil

  defp analyze_sentiment(text) do
    SentimentAnalyzer.analyze(text)
  end

  defp extract_hashtags(response) do
    case get_in(response, [:entities, :hashtags]) do
      nil -> []
      hashtags -> Enum.map(hashtags, & &1.tag)
    end
  end

  defp extract_hashtags_from_text(nil), do: []

  defp extract_hashtags_from_text(text) do
    ~r/#(\w+)/
    |> Regex.scan(text)
    |> Enum.map(fn [_, hashtag] -> hashtag end)
  end

  defp check_rate_limit(state) do
    current_time = System.monotonic_time(:millisecond)
    window_start = state.rate_limit.window_start
    requests = state.rate_limit.requests

    # Reset window if 15 minutes have passed
    {new_window_start, new_requests} =
      if current_time - window_start >= @window_duration do
        {current_time, 0}
      else
        {window_start, requests}
      end

    # Check if we're under the limit
    if new_requests < @max_requests_per_window do
      new_rate_limit = %{
        requests: new_requests + 1,
        window_start: new_window_start
      }

      {:ok, new_rate_limit}
    else
      {:error, :rate_limited}
    end
  end
end
