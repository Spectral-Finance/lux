defmodule Lux.Integrations.Telegram.RateLimiter do
  @moduledoc """
  Rate limiting and request queueing for the Telegram Bot API.

  Telegram Bot API enforces rate limits:
  - ~30 messages per second to different users
  - 1 message per second per chat (bursts allowed)
  - 20 messages per minute to the same group

  This module provides a token-bucket rate limiter with a queue that
  automatically delays requests to stay within limits, and a GenServer
  that serializes requests through the limiter.

  ## Usage

  ### Direct rate limiting

      iex> RateLimiter.check_and_wait(:send_message)
      :ok

  ### With a queue

      iex> RateLimiter.enqueue({:send_message, %{chat_id: 123, text: "hi"}})
      :ok

  ## Configuration

  - `:rate_limit` — requests per second (default: 30)
  - `:burst_limit` — maximum burst size (default: 30)
  """

  use GenServer

  require Logger

  @default_rate_limit 30
  @default_burst_limit 30

  @type bucket :: %{
          tokens: non_neg_integer(),
          rate_limit: non_neg_integer(),
          burst_limit: non_neg_integer(),
          last_refill: integer()
        }

  # Client API

  @doc """
  Starts the rate limiter GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Checks if a request can proceed and waits if necessary.

  Blocks the calling process until a token is available, then consumes it.
  Returns `:ok` when the request may proceed.

  ## Examples

      iex> RateLimiter.check_and_wait(:send_message)
      :ok
  """
  @spec check_and_wait(atom()) :: :ok
  def check_and_wait(operation \\ :default) do
    GenServer.call(__MODULE__, {:check_and_wait, operation})
  end

  @doc """
  Enqueues a request for later processing.

  The request will be processed when rate limits allow.

  ## Examples

      iex> RateLimiter.enqueue({:send_message, %{chat_id: 123}})
      :ok
  """
  @spec enqueue({atom(), map()}) :: :ok
  def enqueue(request) do
    GenServer.cast(__MODULE__, {:enqueue, request})
  end

  @doc """
  Gets the current rate limiter state.

  ## Examples

      iex> RateLimiter.get_state()
      %{tokens: 30, rate_limit: 30, burst_limit: 30, queue_size: 0}
  """
  @spec get_state() :: map()
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc """
  Resets the rate limiter to full capacity.
  """
  @spec reset() :: :ok
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  @doc """
  Returns the default rate limit (requests per second).
  """
  @spec default_rate_limit() :: non_neg_integer()
  def default_rate_limit, do: @default_rate_limit

  @doc """
  Returns the default burst limit.
  """
  @spec default_burst_limit() :: non_neg_integer()
  def default_burst_limit, do: @default_burst_limit

  # GenServer callbacks

  @impl true
  def init(opts) do
    rate_limit = Keyword.get(opts, :rate_limit, @default_rate_limit)
    burst_limit = Keyword.get(opts, :burst_limit, @default_burst_limit)

    state = %{
      bucket: %{
        tokens: burst_limit,
        rate_limit: rate_limit,
        burst_limit: burst_limit,
        last_refill: System.monotonic_time(:millisecond)
      },
      queue: :queue.new()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:check_and_wait, _operation}, _from, state) do
    bucket = refill(state.bucket)

    if bucket.tokens > 0 do
      bucket = %{bucket | tokens: bucket.tokens - 1}
      {:reply, :ok, %{state | bucket: bucket}}
    else
      # Calculate wait time until next token
      wait_ms = ceil(1000 / bucket.rate_limit)
      Process.sleep(wait_ms)
      bucket = refill(bucket)
      bucket = %{bucket | tokens: bucket.tokens - 1}
      {:reply, :ok, %{state | bucket: bucket}}
    end
  end

  def handle_call(:get_state, _from, state) do
    bucket = refill(state.bucket)

    result = %{
      tokens: bucket.tokens,
      rate_limit: bucket.rate_limit,
      burst_limit: bucket.burst_limit,
      queue_size: :queue.len(state.queue)
    }

    {:reply, result, %{state | bucket: bucket}}
  end

  def handle_call(:reset, _from, state) do
    bucket = %{
      state.bucket
      | tokens: state.bucket.burst_limit,
        last_refill: System.monotonic_time(:millisecond)
    }

    {:reply, :ok, %{state | bucket: bucket}}
  end

  @impl true
  def handle_cast({:enqueue, request}, state) do
    queue = :queue.in(request, state.queue)
    {:noreply, %{state | queue: queue}}
  end

  # Private functions

  defp refill(bucket) do
    now = System.monotonic_time(:millisecond)
    elapsed = now - bucket.last_refill
    tokens_to_add = div(elapsed * bucket.rate_limit, 1000)

    new_tokens = min(bucket.tokens + tokens_to_add, bucket.burst_limit)

    %{bucket | tokens: new_tokens, last_refill: now}
  end
end