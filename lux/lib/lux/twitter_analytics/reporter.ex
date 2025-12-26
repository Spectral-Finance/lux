defmodule Lux.TwitterAnalytics.Reporter do
  @moduledoc """
  GenServer for generating customizable Twitter analytics reports.

  Provides various report types:
  - Engagement summary
  - Top performing tweets
  - Sentiment analysis
  - Hashtag trends
  - Follower growth (when user monitoring is active)
  """
  use GenServer
  require Logger

  alias Lux.TwitterAnalytics.Aggregator

  ## Client API

  @doc """
  Start the Reporter GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Generate an engagement summary report.

  ## Options
    * `:start_time` - Start of time range (DateTime)
    * `:end_time` - End of time range (DateTime)
  """
  def engagement_summary(opts \\ []) do
    GenServer.call(__MODULE__, {:generate_report, :engagement_summary, opts})
  end

  @doc """
  Generate a top performing tweets report.

  ## Options
    * `:limit` - Number of top tweets to return (default: 10)
    * `:start_time` - Start of time range (DateTime)
    * `:end_time` - End of time range (DateTime)
  """
  def top_performing(opts \\ []) do
    GenServer.call(__MODULE__, {:generate_report, :top_performing, opts})
  end

  @doc """
  Generate a sentiment analysis report.

  ## Options
    * `:start_time` - Start of time range (DateTime)
    * `:end_time` - End of time range (DateTime)
  """
  def sentiment_analysis(opts \\ []) do
    GenServer.call(__MODULE__, {:generate_report, :sentiment_analysis, opts})
  end

  @doc """
  Generate a hashtag trends report.

  ## Options
    * `:hashtag` - Specific hashtag to analyze (required)
    * `:start_time` - Start of time range (DateTime)
    * `:end_time` - End of time range (DateTime)
  """
  def hashtag_trends(opts \\ []) do
    GenServer.call(__MODULE__, {:generate_report, :hashtag_trends, opts})
  end

  @doc """
  Generate a custom report.
  """
  def custom_report(report_fn, opts \\ []) do
    GenServer.call(__MODULE__, {:custom_report, report_fn, opts})
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting TwitterAnalytics.Reporter")
    {:ok, %{}}
  end

  @impl true
  def handle_call({:generate_report, :engagement_summary, opts}, _from, state) do
    {start_time, end_time} = get_time_range(opts)

    result =
      with {:ok, summary} <- Aggregator.get_engagement_summary(start_time, end_time) do
        {:ok,
         %{
           type: :engagement_summary,
           data: summary,
           generated_at: DateTime.utc_now()
         }}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:generate_report, :top_performing, opts}, _from, state) do
    {start_time, end_time} = get_time_range(opts)
    limit = Keyword.get(opts, :limit, 10)

    result =
      with {:ok, tweets} <-
             Aggregator.get_top_tweets(start_time: start_time, end_time: end_time, limit: limit) do
        {:ok,
         %{
           type: :top_performing,
           data: %{
             tweets: tweets,
             count: length(tweets)
           },
           generated_at: DateTime.utc_now()
         }}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:generate_report, :sentiment_analysis, opts}, _from, state) do
    {start_time, end_time} = get_time_range(opts)

    result =
      with {:ok, sentiment_data} <- Aggregator.get_sentiment_distribution(start_time, end_time) do
        {:ok,
         %{
           type: :sentiment_analysis,
           data: sentiment_data,
           period: %{start: start_time, end: end_time},
           generated_at: DateTime.utc_now()
         }}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:generate_report, :hashtag_trends, opts}, _from, state) do
    hashtag = Keyword.get(opts, :hashtag)

    if is_nil(hashtag) do
      {:reply, {:error, :hashtag_required}, state}
    else
      {start_time, end_time} = get_time_range(opts)

      result =
        with {:ok, performance} <-
               Aggregator.get_hashtag_performance(hashtag, start_time, end_time) do
          {:ok,
           %{
             type: :hashtag_trends,
             data: performance,
             generated_at: DateTime.utc_now()
           }}
        end

      {:reply, result, state}
    end
  end

  @impl true
  def handle_call({:custom_report, report_fn, opts}, _from, state) when is_function(report_fn) do
    {start_time, end_time} = get_time_range(opts)

    result =
      try do
        data = report_fn.(start_time, end_time, opts)

        {:ok,
         %{
           type: :custom,
           data: data,
           generated_at: DateTime.utc_now()
         }}
      rescue
        error ->
          Logger.error("Custom report error: #{inspect(error)}")
          {:error, :report_generation_failed}
      end

    {:reply, result, state}
  end

  ## Private Functions

  defp get_time_range(opts) do
    default_start = DateTime.add(DateTime.utc_now(), -7, :day)
    default_end = DateTime.utc_now()

    start_time = Keyword.get(opts, :start_time, default_start)
    end_time = Keyword.get(opts, :end_time, default_end)

    {start_time, end_time}
  end
end
