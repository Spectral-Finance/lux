defmodule Lux.Integrations.Twitter.Analytics.Monitor do
  @moduledoc """
  Twitter engagement analytics and real-time monitoring.

  Collects tweet engagement metrics, tracks follower growth, analyzes hashtag
  performance and mention sentiment, defines custom metrics, evaluates
  engagement-threshold alerts and generates customizable reports.

  All state is held in an ETS table owned by the monitor GenServer, so every
  state transition is atomic and safe under concurrent collection. Every public
  operation returns `{:ok, result}` on success or `{:error, reason}` with a
  typed reason on failure; invalid input never crashes the caller.

  ## Examples

      {:ok, monitor} = Lux.Integrations.Twitter.Analytics.Monitor.start_link()

      {:ok, metric} =
        Lux.Integrations.Twitter.Analytics.Monitor.record_engagement(
          monitor,
          "192.0.2.3",
          %{likes: 10, retweets: 5, replies: 2}
        )

      alerts = Lux.Integrations.Twitter.Analytics.Monitor.check_alerts(monitor)

  """

  require Logger

  use GenServer

  @engagement_keys ~w[likes retweets replies impressions mentions]a
  @positive_words ~w[good great excellent amazing wonderful fantastic love loves
                     liked best perfect awesome brilliant happy pleased impressed
                     outstanding superior]
  @negative_words ~w[bad terrible awful horrible hate hates hated worst poor
                     dislike dislikes boring dull]
  @sentiment_threshold 0.05

  @type engagement_metric ::
          %{
            likes: non_neg_integer(),
            retweets: non_neg_integer(),
            replies: non_neg_integer(),
            impressions: non_neg_integer(),
            mentions: non_neg_integer()
          }

  @type threshold :: {number(), :above | :below}

  @type metric :: %{
          id: String.t(),
          kind: :engagement | :follower_growth | :hashtag | :custom,
          name: String.t(),
          value: number(),
          threshold: threshold() | nil,
          direction: :above | :below | nil,
          data: map(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @type alert :: %{
          metric_id: String.t(),
          metric_name: String.t(),
          value: number(),
          threshold: number(),
          direction: :above | :below,
          fired_at: DateTime.t()
        }

  # === Client API ===

  @doc """
  Starts the monitor under a supervisor.

  ## Options

    * `:name` - registered name, handled by the underlying GenServer
    * `:api_key` - optional Twitter API bearer token. When configured, every
      mutating call must pass a matching `:api_key` in its options or it is
      refused with `{:error, :unauthorized}`.

  """
  @spec start_link(Keyword.t()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Starts the monitor without linking.

  See `start_link/1` for supported options.
  """
  @spec start(Keyword.t()) :: {:ok, pid()} | {:error, term()}
  def start(opts \\ []) do
    GenServer.start(__MODULE__, opts)
  end

  @doc """
  Records engagement metrics for `tweet_id`.

  The call is idempotent: recording the same `tweet_id` twice returns
  `{:error, :duplicate}`, which makes concurrent collection safe and free of
  double-counting.

  ## Options

    * `:api_key` - required when the monitor was started with `:api_key`

  """
  @spec record_engagement(pid() | atom(), String.t(), map(), Keyword.t()) ::
          {:ok, metric()} | {:error, atom()}
  def record_engagement(server, tweet_id, metrics \\ %{}, opts \\ []) do
    GenServer.call(server, {:record_engagement, tweet_id, metrics, opts})
  end

  @doc """
  Tracks follower growth for `account`.

  The follower count is upserted per account and the growth delta since the
  previous sample is recorded in `data.growth`.

  ## Options

    * `:api_key` - required when the monitor was started with `:api_key`

  """
  @spec track_follower_growth(pid() | atom(), String.t(), integer(), Keyword.t()) ::
          {:ok, metric()} | {:error, atom()}
  def track_follower_growth(server, account, count, opts \\ []) do
    GenServer.call(server, {:track_follower_growth, account, count, opts})
  end

  @doc """
  Analyzes hashtag performance for `hashtag` over a list of tweets.

  Each tweet may carry an `:engagement` map. The hashtag metric is upserted
  into the store and a summary analysis is returned.

  ## Options

    * `:api_key` - required when the monitor was started with `:api_key`

  """
  @spec analyze_hashtag(pid() | atom(), String.t(), list()) ::
          {:ok, map()} | {:error, atom()}
  def analyze_hashtag(server, hashtag, tweets, opts \\ []) do
    GenServer.call(server, {:analyze_hashtag, hashtag, tweets, opts})
  end

  @doc """
  Analyzes the sentiment of a mention text.

  This is a pure, deterministic lexicon-based analysis that needs no external
  API or configuration.

  """
  @spec analyze_sentiment(String.t()) :: {:ok, map()}
  def analyze_sentiment(text) do
    {:ok, compute_sentiment(text)}
  end

  @doc """
  Defines a custom metric with an optional engagement-threshold alert.

  `threshold` is `nil`, `{value, :above}` or `{value, :below}`. The metric is
  created with an initial value of `0`.

  ## Options

    * `:api_key` - required when the monitor was started with `:api_key`

  """
  @spec define_metric(pid() | atom(), String.t(), threshold() | nil, Keyword.t()) ::
          {:ok, metric()} | {:error, atom()}
  def define_metric(server, name, threshold, opts \\ []) do
    GenServer.call(server, {:define_metric, name, threshold, opts})
  end

  @doc """
  Atomically increments `metric` by `delta` (defaults to `1`), creating it
  with an initial value of `0` when it does not exist yet.

  Returns `{:ok, new_value}`.

  ## Options

    * `:api_key` - required when the monitor was started with `:api_key`

  """
  @spec increment_metric(pid() | atom(), String.t(), number(), Keyword.t()) ::
          {:ok, number()} | {:error, atom()}
  def increment_metric(server, id, delta \\ 1, opts \\ []) do
    GenServer.call(server, {:increment_metric, id, delta, opts})
  end

  @doc """
  Sets the value of `metric` to `value`, creating it when it does not exist.

  Returns `{:ok, metric}`.

  ## Options

    * `:api_key` - required when the monitor was started with `:api_key`

  """
  @spec update_metric(pid() | atom(), String.t(), number(), Keyword.t()) ::
          {:ok, metric()} | {:error, atom()}
  def update_metric(server, id, value, opts \\ []) do
    GenServer.call(server, {:update_metric, id, value, opts})
  end

  @doc """
  Evaluates every metric that carries a threshold and returns the list of
  alerts currently fired.
  """
  @spec check_alerts(pid() | atom()) :: {:ok, list(alert())}
  def check_alerts(server) do
    GenServer.call(server, :check_alerts)
  end

  @doc """
  Collects every stored metric and aggregates it into a report data structure.
  """
  @spec collect_metrics(pid() | atom()) :: {:ok, map()}
  def collect_metrics(server) do
    GenServer.call(server, :collect_metrics)
  end

  @doc """
  Generates a customizable report.

  ## Options

    * `:include` - list of sections to include, defaults to
      `[:summary, :metrics, :alerts]`

  """
  @spec generate_report(pid() | atom(), Keyword.t()) :: {:ok, map()}
  def generate_report(server, opts \\ []) do
    GenServer.call(server, {:generate_report, opts})
  end

  @doc """
  Fetches a single stored metric by `id`.
  """
  @spec get_metric(pid() | atom(), String.t()) :: {:ok, metric()} | {:error, atom()}
  def get_metric(server, id) do
    GenServer.call(server, {:get_metric, id})
  end

  @doc """
  Lists every stored metric, sorted by id.
  """
  @spec list_metrics(pid() | atom()) :: {:ok, list(metric())}
  def list_metrics(server) do
    GenServer.call(server, :list_metrics)
  end

  @doc """
  Deletes a stored metric by `id`.

  ## Options

    * `:api_key` - required when the monitor was started with `:api_key`

  """
  @spec delete_metric(pid() | atom(), String.t(), Keyword.t()) ::
          {:ok, atom()} | {:error, atom()}
  def delete_metric(server, id, opts \\ []) do
    GenServer.call(server, {:delete_metric, id, opts})
  end

  # === GenServer callbacks ===

  @impl true
  def init(opts) do
    table = :ets.new(:monitor, [:set, :protected])
    {:ok, %{table: table, api_key: Keyword.get(opts, :api_key)}}
  end

  @impl true
  def handle_call({:record_engagement, tweet_id, metrics, opts}, _from, state) do
    result =
      cond do
        not authorized?(state, opts) ->
          {:error, :unauthorized}

        not valid_id?(tweet_id) ->
          {:error, :invalid_tweet_id}

        not is_map(metrics) ->
          {:error, :invalid_metrics}

        true ->
          case validate_engagement(metrics) do
            {:ok, metrics} -> put_engagement(state.table, tweet_id, metrics)
            {:error, reason} -> {:error, reason}
          end
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:track_follower_growth, account, count, opts}, _from, state) do
    result =
      cond do
        not authorized?(state, opts) ->
          {:error, :unauthorized}

        not valid_id?(account) ->
          {:error, :invalid_account}

        not is_integer(count) ->
          {:error, :invalid_count}

        count < 0 ->
          {:error, :negative_value}

        true ->
          put_follower(state.table, account, count)
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:analyze_hashtag, hashtag, tweets, opts}, _from, state) do
    result =
      cond do
        not authorized?(state, opts) ->
          {:error, :unauthorized}

        not valid_hashtag?(hashtag) ->
          {:error, :invalid_hashtag}

        not is_list(tweets) ->
          {:error, :invalid_tweets}

        true ->
          analyze_hashtag_data(state.table, hashtag, tweets)
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:define_metric, name, threshold, opts}, _from, state) do
    result =
      cond do
        not authorized?(state, opts) ->
          {:error, :unauthorized}

        not valid_id?(name) ->
          {:error, :invalid_name}

        true ->
          case validate_threshold(threshold) do
            {:ok, threshold} -> put_custom_metric(state.table, name, threshold)
            {:error, reason} -> {:error, reason}
          end
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:increment_metric, id, delta, opts}, _from, state) do
    result =
      cond do
        not authorized?(state, opts) ->
          {:error, :unauthorized}

        not valid_id?(id) ->
          {:error, :invalid_metric_id}

        not is_number(delta) ->
          {:error, :invalid_delta}

        true ->
          do_increment_metric(state.table, id, delta)
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:update_metric, id, value, opts}, _from, state) do
    result =
      cond do
        not authorized?(state, opts) ->
          {:error, :unauthorized}

        not valid_id?(id) ->
          {:error, :invalid_metric_id}

        not is_number(value) ->
          {:error, :invalid_value}

        true ->
          put_value(state.table, id, value)
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:check_alerts, _from, state) do
    {:reply, {:ok, check_alerts_data(state.table)}, state}
  end

  @impl true
  def handle_call(:collect_metrics, _from, state) do
    {:reply, {:ok, collect_metrics_data(state.table)}, state}
  end

  @impl true
  def handle_call({:generate_report, opts}, _from, state) do
    sections = Keyword.get(opts, :include, [:summary, :metrics, :alerts])
    data = collect_metrics_data(state.table)
    alerts = check_alerts_data(state.table)

    report = %{}
    report = if :summary in sections, do: put_in(report, [:summary], summary(data)), else: report
    report = if :metrics in sections, do: put_in(report, [:metrics], data), else: report
    report = if :alerts in sections, do: put_in(report, [:alerts], alerts), else: report

    {:reply, {:ok, report}, state}
  end

  @impl true
  def handle_call({:get_metric, id}, _from, state) do
    result =
      case :ets.lookup(state.table, id) do
        [{^id, metric}] when is_map(metric) -> {:ok, metric}
        _ -> {:error, :not_found}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:list_metrics, _from, state) do
    metrics =
      :ets.tab2list(state.table)
      |> Enum.map(fn {_id, metric} -> metric end)
      |> Enum.filter(&is_map/1)
      |> Enum.sort_by(& &1.id)

    {:reply, {:ok, metrics}, state}
  end

  @impl true
  def handle_call({:delete_metric, id, opts}, _from, state) do
    result =
      cond do
        not authorized?(state, opts) ->
          {:error, :unauthorized}

        not valid_id?(id) ->
          {:error, :invalid_metric_id}

        :ets.lookup(state.table, id) == [] ->
          {:error, :not_found}

        true ->
          :ets.delete(state.table, id)
          {:ok, :deleted}
      end

    {:reply, result, state}
  end

  # === Internal helpers ===

  defp authorized?(%{api_key: nil}, _opts), do: true

  defp authorized?(%{api_key: expected}, opts) do
    Keyword.get(opts, :api_key) == expected
  end

  defp valid_id?(id), do: is_binary(id) and String.trim(id) != ""

  defp valid_hashtag?(hashtag) do
    is_binary(hashtag) and String.starts_with?(hashtag, "#") and String.length(hashtag) > 1
  end

  defp validate_engagement(metrics) do
    cond do
      Enum.any?(metrics, fn {key, _} -> key not in @engagement_keys end) ->
        {:error, :invalid_metrics}

      Enum.any?(metrics, fn {_key, value} -> not is_integer(value) end) ->
        {:error, :invalid_metrics}

      Enum.any?(metrics, fn {_key, value} -> value < 0 end) ->
        {:error, :negative_value}

      true ->
        normalized =
          Enum.reduce(@engagement_keys, %{}, fn key, acc ->
            Map.put(acc, key, Map.get(metrics, key, 0))
          end)

        {:ok, normalized}
    end
  end

  defp validate_threshold(nil), do: {:ok, nil}
  defp validate_threshold({value, :above}) when is_number(value), do: {:ok, {value, :above}}
  defp validate_threshold({value, :below}) when is_number(value), do: {:ok, {value, :below}}
  defp validate_threshold(_), do: {:error, :invalid_threshold}

  defp threshold_parts({value, :above}), do: {value, :above}
  defp threshold_parts({value, :below}), do: {value, :below}

  defp put_engagement(table, tweet_id, metrics) do
    now = DateTime.utc_now()
    total = Map.values(metrics) |> Enum.sum()

    entry = %{
      id: tweet_id,
      kind: :engagement,
      name: "engagement:#{tweet_id}",
      value: total,
      threshold: nil,
      direction: nil,
      data: %{tweet_id: tweet_id, metrics: metrics},
      created_at: now,
      updated_at: now
    }

    case :ets.insert_new(table, {tweet_id, entry}) do
      true -> {:ok, entry}
      false -> {:error, :duplicate}
    end
  end

  defp put_follower(table, account, count) do
    now = DateTime.utc_now()

    case :ets.lookup(table, account) do
      [{^account, previous}] when is_map(previous) ->
        if previous.kind == :follower_growth do
          growth = count - previous.value

          entry =
            %{
              previous
              | value: count,
                data: %{account: account, previous: previous.value, growth: growth},
                updated_at: now
            }

          :ets.insert(table, {account, entry})
          {:ok, entry}
        else
          create_follower(table, account, count, now)
        end

      [] ->
        create_follower(table, account, count, now)
    end
  end

  defp create_follower(table, account, count, now) do
    entry = %{
      id: account,
      kind: :follower_growth,
      name: "followers:#{account}",
      value: count,
      threshold: nil,
      direction: nil,
      data: %{account: account, previous: 0, growth: count},
      created_at: now,
      updated_at: now
    }

    :ets.insert(table, {account, entry})
    {:ok, entry}
  end

  defp analyze_hashtag_data(table, hashtag, tweets) do
    totals =
      Enum.map(tweets, fn tweet ->
        engagement = Map.get(tweet, :engagement, %{})
        Map.values(engagement) |> Enum.sum()
      end)

    tweet_count = length(tweets)
    total_engagement = Enum.sum(totals)

    average_engagement =
      if tweet_count > 0, do: total_engagement / tweet_count, else: 0

    {top_tweet, _top_total} =
      Enum.reduce(tweets, {nil, 0}, fn tweet, {best, best_total} ->
        engagement = Map.get(tweet, :engagement, %{})
        total = Map.values(engagement) |> Enum.sum()

        if total > best_total, do: {tweet, total}, else: {best, best_total}
      end)

    now = DateTime.utc_now()

    entry = %{
      id: hashtag,
      kind: :hashtag,
      name: hashtag,
      value: tweet_count,
      threshold: nil,
      direction: nil,
      data: %{
        hashtag: hashtag,
        tweet_count: tweet_count,
        total_engagement: total_engagement,
        average_engagement: average_engagement,
        top_tweet: top_tweet
      },
      created_at: now,
      updated_at: now
    }

    :ets.insert(table, {hashtag, entry})

    {:ok,
     %{
       hashtag: hashtag,
       tweet_count: tweet_count,
       total_engagement: total_engagement,
       average_engagement: average_engagement,
       top_tweet: top_tweet
     }}
  end

  # Pure, deterministic sentiment analysis with no external dependencies.
  defp compute_sentiment(text) do
    tokens = tokenize(text)
    {pos, neg, neu} = classify(tokens)
    total = length(tokens)
    compound = if total > 0, do: (pos - neg) / total, else: 0.0
    compound = clamp(compound, -1.0, 1.0)
    confidence = abs(compound)

    sentiment =
      cond do
        compound >= @sentiment_threshold -> :positive
        compound <= -@sentiment_threshold -> :negative
        true -> :neutral
      end

    %{
      sentiment: sentiment,
      confidence: round_precision(confidence, 4),
      details: %{pos: pos, neg: neg, neu: neu, compound: compound}
    }
  end

  defp tokenize(text) do
    String.downcase(text)
    |> String.split(~r/\W+/)
    |> Enum.reject(&(&1 == ""))
  end

  defp classify(tokens) do
    Enum.reduce(tokens, {0, 0, 0}, fn token, {pos, neg, neu} ->
      cond do
        token in @positive_words -> {pos + 1, neg, neu}
        token in @negative_words -> {pos, neg + 1, neu}
        true -> {pos, neg, neu + 1}
      end
    end)
  end

  defp clamp(value, min, max) do
    cond do
      value < min -> min
      value > max -> max
      true -> value
    end
  end

  defp round_precision(value, precision) do
    factor = :math.pow(10, precision)
    :math.floor(value * factor + 0.5) / factor
  end

  defp put_custom_metric(table, name, threshold) do
    now = DateTime.utc_now()

    {_value, direction} =
      case threshold do
        nil -> {0, nil}
        {v, :above} -> {v, :above}
        {v, :below} -> {v, :below}
      end

    entry = %{
      id: name,
      kind: :custom,
      name: name,
      value: 0,
      threshold: threshold,
      direction: direction,
      data: %{},
      created_at: now,
      updated_at: now
    }

    :ets.insert(table, {name, entry})
    {:ok, entry}
  end

  defp do_increment_metric(table, id, delta) do
    now = DateTime.utc_now()

    case :ets.lookup(table, id) do
      [{^id, metric}] when is_map(metric) ->
        new_value = metric.value + delta
        entry = %{metric | value: new_value, updated_at: now}
        :ets.insert(table, {id, entry})
        {:ok, new_value}

      [] ->
        entry = %{
          id: id,
          kind: :custom,
          name: id,
          value: delta,
          threshold: nil,
          direction: nil,
          data: %{},
          created_at: now,
          updated_at: now
        }

        :ets.insert(table, {id, entry})
        {:ok, delta}
    end
  end

  defp put_value(table, id, value) do
    now = DateTime.utc_now()

    case :ets.lookup(table, id) do
      [{^id, metric}] when is_map(metric) ->
        entry = %{metric | value: value, updated_at: now}
        :ets.insert(table, {id, entry})
        {:ok, entry}

      [] ->
        entry = %{
          id: id,
          kind: :custom,
          name: id,
          value: value,
          threshold: nil,
          direction: nil,
          data: %{},
          created_at: now,
          updated_at: now
        }

        :ets.insert(table, {id, entry})
        {:ok, entry}
    end
  end

  defp collect_metrics_data(table) do
    metrics =
      :ets.tab2list(table)
      |> Enum.map(fn {_id, metric} -> metric end)
      |> Enum.filter(&is_map/1)
      |> Enum.sort_by(& &1.id)

    engagements = Enum.filter(metrics, &(&1.kind == :engagement))
    followers = Enum.filter(metrics, &(&1.kind == :follower_growth))
    hashtags = Enum.filter(metrics, &(&1.kind == :hashtag))
    custom = Enum.filter(metrics, &(&1.kind == :custom))

    engagement_totals =
      Enum.reduce(
        engagements,
        %{likes: 0, retweets: 0, replies: 0, impressions: 0, mentions: 0},
        fn metric, acc ->
          engagement = Map.get(metric.data, :metrics, %{})

          Enum.reduce(@engagement_keys, acc, fn key, acc ->
            Map.update!(acc, key, &(&1 + Map.get(engagement, key, 0)))
          end)
        end
      )

    %{
      engagements: engagements,
      followers: followers,
      hashtags: hashtags,
      custom: custom,
      totals: %{
        total_metrics: length(metrics),
        total_likes: engagement_totals.likes,
        total_retweets: engagement_totals.retweets,
        total_replies: engagement_totals.replies,
        total_impressions: engagement_totals.impressions,
        total_mentions: engagement_totals.mentions
      }
    }
  end

  defp check_alerts_data(table) do
    now = DateTime.utc_now()

    :ets.tab2list(table)
    |> Enum.filter(fn {_id, metric} -> is_map(metric) and metric.threshold != nil end)
    |> Enum.flat_map(fn {_id, metric} ->
      {value, direction} = threshold_parts(metric.threshold)

      fired =
        cond do
          direction == :above and metric.value > value -> true
          direction == :below and metric.value < value -> true
          true -> false
        end

      if fired do
        [
          %{
            metric_id: metric.id,
            metric_name: metric.name,
            value: metric.value,
            threshold: value,
            direction: direction,
            fired_at: now
          }
        ]
      else
        []
      end
    end)
  end

  defp summary(data) do
    %{
      total_metrics: data.totals.total_metrics,
      total_engagement:
        data.totals.total_likes + data.totals.total_retweets +
          data.totals.total_replies + data.totals.total_mentions,
      engagements: length(data.engagements),
      followers: length(data.followers),
      hashtags: length(data.hashtags),
      custom_metrics: length(data.custom)
    }
  end
end
