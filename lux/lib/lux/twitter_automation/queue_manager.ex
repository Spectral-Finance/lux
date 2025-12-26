defmodule Lux.TwitterAutomation.QueueManager do
  @moduledoc """
  Manages the action queue and rate limiting for Twitter API calls.

  Handles:
  - Queueing actions with priorities
  - Rate limit tracking (tweets, follows, unfollows, DMs)
  - Action execution via Twitter lenses
  - Retry logic for rate-limited actions
  """

  use GenServer
  require Logger

  alias Lux.TwitterAutomation.Storage
  alias Lux.Lenses.Twitter.{CreateTweet, DeleteTweet, FollowUser, UnfollowUser, SendDirectMessage}

  # Twitter API rate limits (conservative)
  @tweet_limit %{max: 300, window: 3 * 60 * 60 * 1000}  # 300 per 3 hours
  @follow_limit %{max: 50, window: 60 * 60 * 1000}      # 50 per hour (conservative)
  @unfollow_limit %{max: 15, window: 60 * 60 * 1000}    # 15 per hour
  @dm_limit %{max: 15, window: 15 * 60 * 1000}          # 15 per 15 minutes

  @process_interval 5_000  # Process queue every 5 seconds

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Enqueue an action"
  def enqueue(action_type, payload, priority \\ :normal) do
    GenServer.call(__MODULE__, {:enqueue, action_type, payload, priority})
  end

  @doc "Get queue size"
  def get_queue_size do
    GenServer.call(__MODULE__, :get_queue_size)
  end

  @doc "Get rate limit status"
  def get_rate_limit_status do
    GenServer.call(__MODULE__, :get_rate_limit_status)
  end

  @doc "Force process next item"
  def process_now do
    GenServer.cast(__MODULE__, :process_queue)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Storage.init()
    schedule_processing()

    {:ok,
     %{
       rate_limits: %{
         tweets: init_rate_limit(@tweet_limit),
         follows: init_rate_limit(@follow_limit),
         unfollows: init_rate_limit(@unfollow_limit),
         dms: init_rate_limit(@dm_limit)
       },
       processing: false
     }}
  end

  @impl true
  def handle_call({:enqueue, action_type, payload, priority}, _from, state) do
    action = %{
      id: generate_id(),
      action_type: action_type,
      payload: payload,
      priority: priority,
      created_at: DateTime.utc_now(),
      status: :pending,
      retries: 0
    }

    Storage.enqueue_action(action)
    Logger.info("Enqueued #{action_type} action (priority: #{priority})")

    {:reply, {:ok, action.id}, state}
  end

  @impl true
  def handle_call(:get_queue_size, _from, state) do
    size = Storage.get_queue_size()
    {:reply, size, state}
  end

  @impl true
  def handle_call(:get_rate_limit_status, _from, state) do
    status = %{
      tweets: get_available_requests(state.rate_limits.tweets, @tweet_limit),
      follows: get_available_requests(state.rate_limits.follows, @follow_limit),
      unfollows: get_available_requests(state.rate_limits.unfollows, @unfollow_limit),
      dms: get_available_requests(state.rate_limits.dms, @dm_limit)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast(:process_queue, state) do
    new_state = process_next_action(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:process_queue, state) do
    schedule_processing()
    new_state = if state.processing, do: state, else: process_next_action(state)
    {:noreply, new_state}
  end

  ## Private Functions

  defp schedule_processing do
    Process.send_after(self(), :process_queue, @process_interval)
  end

  defp process_next_action(state) do
    case Storage.dequeue_action() do
      {:ok, nil} ->
        state

      {:ok, action} ->
        process_action(action, state)
    end
  end

  defp process_action(action, state) do
    rate_limit_key = action_type_to_rate_limit(action.action_type)
    rate_limit = state.rate_limits[rate_limit_key]
    limit_config = get_limit_config(rate_limit_key)

    # Clean expired requests
    cleaned_limit = clean_rate_limit(rate_limit, limit_config)

    if can_make_request?(cleaned_limit, limit_config) do
      execute_action(action, rate_limit_key, cleaned_limit, state)
    else
      # Re-queue with backoff
      Logger.warn("Rate limit reached for #{action.action_type}, re-queueing")
      Storage.enqueue_action(%{action | retries: action.retries + 1})
      state
    end
  end

  defp execute_action(action, rate_limit_key, current_limit, state) do
    Logger.info("Executing #{action.action_type} action")

    result =
      case action.action_type do
        :create_tweet -> CreateTweet.focus(action.payload)
        :delete_tweet -> DeleteTweet.focus(action.payload)
        :follow_user -> FollowUser.focus(action.payload)
        :unfollow_user -> UnfollowUser.focus(action.payload)
        :send_dm -> SendDirectMessage.focus(action.payload)
        _ -> {:error, :unknown_action_type}
      end

    case result do
      {:ok, _response} ->
        Logger.info("Successfully executed #{action.action_type}")
        # Track request
        new_limit = track_request(current_limit)
        put_in(state, [:rate_limits, rate_limit_key], new_limit)

      {:error, error} ->
        Logger.error("Failed to execute #{action.action_type}: #{inspect(error)}")

        # Re-queue if retryable
        if action.retries < 3 do
          Storage.enqueue_action(%{action | retries: action.retries + 1})
        end

        state
    end
  end

  # Rate limit helpers

  defp init_rate_limit(_config) do
    %{requests: [], window_start: DateTime.utc_now()}
  end

  defp clean_rate_limit(limit, config) do
    now = DateTime.utc_now()
    cutoff = DateTime.add(now, -config.window, :millisecond)

    recent_requests = Enum.filter(limit.requests, fn timestamp ->
      DateTime.compare(timestamp, cutoff) == :gt
    end)

    %{limit | requests: recent_requests}
  end

  defp can_make_request?(limit, config) do
    length(limit.requests) < config.max
  end

  defp track_request(limit) do
    %{limit | requests: [DateTime.utc_now() | limit.requests]}
  end

  defp get_available_requests(limit, config) do
    config.max - length(limit.requests)
  end

  # Mapping helpers

  defp action_type_to_rate_limit(:create_tweet), do: :tweets
  defp action_type_to_rate_limit(:delete_tweet), do: :tweets
  defp action_type_to_rate_limit(:follow_user), do: :follows
  defp action_type_to_rate_limit(:unfollow_user), do: :unfollows
  defp action_type_to_rate_limit(:send_dm), do: :dms
  defp action_type_to_rate_limit(_), do: :tweets

  defp get_limit_config(:tweets), do: @tweet_limit
  defp get_limit_config(:follows), do: @follow_limit
  defp get_limit_config(:unfollows), do: @unfollow_limit
  defp get_limit_config(:dms), do: @dm_limit

  # Utility

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
