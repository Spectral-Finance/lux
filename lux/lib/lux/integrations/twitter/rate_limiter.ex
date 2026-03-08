defmodule Lux.Integrations.Twitter.RateLimiter do
  @moduledoc """
  Rate limiter for Twitter API v2 requests.

  Tracks per-endpoint rate limits based on response headers and automatically
  delays requests when limits are approaching or exceeded.

  Twitter API v2 rate limits vary by endpoint:
  - Tweet lookup: 300 req/15min (app), 900 req/15min (user)
  - Search: 300 req/15min (app), 180 req/15min (user)
  - User lookup: 300 req/15min (app), 900 req/15min (user)
  - Create tweet: 200 req/15min (user)

  ## Usage

      {:ok, pid} = Lux.Integrations.Twitter.RateLimiter.start_link()

      # Check before making a request
      :ok = Lux.Integrations.Twitter.RateLimiter.check(pid, "/2/tweets")

      # Update after receiving response headers
      Lux.Integrations.Twitter.RateLimiter.update(pid, "/2/tweets", %{
        remaining: 295,
        limit: 300,
        reset_at: 1704067500
      })
  """

  use GenServer
  require Logger

  @window_seconds 900
  @min_remaining 5

  defmodule State do
    @moduledoc false
    defstruct endpoints: %{}
  end

  defmodule EndpointLimit do
    @moduledoc false
    defstruct [:remaining, :limit, :reset_at, :last_request_at]
  end

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @doc """
  Check if a request to the given endpoint is allowed.
  Returns `:ok` or `{:wait, milliseconds}` if rate limited.
  """
  def check(pid, endpoint) do
    GenServer.call(pid, {:check, endpoint})
  end

  @doc """
  Wait until the endpoint is available, then return `:ok`.
  Blocks the calling process if rate limited.
  """
  def wait_and_proceed(pid, endpoint) do
    case check(pid, endpoint) do
      :ok ->
        :ok

      {:wait, ms} ->
        Logger.info("Twitter rate limiter: waiting #{ms}ms for #{endpoint}")
        Process.sleep(ms)
        wait_and_proceed(pid, endpoint)
    end
  end

  @doc """
  Update rate limit info for an endpoint from response headers.
  """
  def update(pid, endpoint, rate_limit) do
    GenServer.cast(pid, {:update, endpoint, rate_limit})
  end

  @doc """
  Record that a 429 was received for an endpoint.
  """
  def record_rate_limited(pid, endpoint, reset_at \\ nil) do
    GenServer.cast(pid, {:rate_limited, endpoint, reset_at})
  end

  @doc "Get current rate limit state for all endpoints."
  def status(pid) do
    GenServer.call(pid, :status)
  end

  @doc "Reset rate limit tracking for an endpoint."
  def reset(pid, endpoint) do
    GenServer.cast(pid, {:reset, endpoint})
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    {:ok, %State{}}
  end

  @impl true
  def handle_call({:check, endpoint}, _from, state) do
    now = System.system_time(:second)

    case Map.get(state.endpoints, endpoint) do
      nil ->
        {:reply, :ok, state}

      %EndpointLimit{remaining: remaining, reset_at: reset_at}
      when is_integer(remaining) and remaining <= @min_remaining and
             is_integer(reset_at) and reset_at > now ->
        wait_ms = (reset_at - now) * 1_000
        {:reply, {:wait, wait_ms}, state}

      %EndpointLimit{remaining: 0, reset_at: reset_at}
      when is_integer(reset_at) and reset_at > now ->
        wait_ms = (reset_at - now) * 1_000
        {:reply, {:wait, wait_ms}, state}

      _ ->
        {:reply, :ok, state}
    end
  end

  def handle_call(:status, _from, state) do
    {:reply, state.endpoints, state}
  end

  @impl true
  def handle_cast({:update, endpoint, rate_limit}, state) do
    limit = %EndpointLimit{
      remaining: rate_limit[:remaining] || rate_limit["remaining"],
      limit: rate_limit[:limit] || rate_limit["limit"],
      reset_at: rate_limit[:reset_at] || rate_limit["reset_at"],
      last_request_at: System.system_time(:second)
    }

    endpoints = Map.put(state.endpoints, endpoint, limit)
    {:noreply, %{state | endpoints: endpoints}}
  end

  def handle_cast({:rate_limited, endpoint, reset_at}, state) do
    reset = reset_at || System.system_time(:second) + @window_seconds

    limit = %EndpointLimit{
      remaining: 0,
      limit: Map.get(state.endpoints, endpoint, %EndpointLimit{}).limit,
      reset_at: reset,
      last_request_at: System.system_time(:second)
    }

    endpoints = Map.put(state.endpoints, endpoint, limit)
    {:noreply, %{state | endpoints: endpoints}}
  end

  def handle_cast({:reset, endpoint}, state) do
    endpoints = Map.delete(state.endpoints, endpoint)
    {:noreply, %{state | endpoints: endpoints}}
  end
end
