defmodule Lux.Integrations.Binance.RateLimiter do
  @moduledoc """
  Token bucket rate limiter for Binance API requests.

  Binance enforces strict rate limits per API key:
  - Spot: 1200 requests per minute (weighted by endpoint)
  - Futures: 1200 requests per minute (weighted by endpoint)

  This module uses ETS to maintain token buckets that
  are refilled at configured rates. Requests consume
  tokens and are blocked when the bucket is empty.
  """

  use GenServer

  require Logger

  @default_spot_rpm 1150
  @default_futures_rpm 1150
  @default_order_rps 8
  @refill_interval_ms 100

  @typedoc "Rate limit configuration"
  @type rate_limit_config :: %{
    spot_rpm: non_neg_integer(),
    futures_rpm: non_neg_integer(),
    order_rps: non_neg_integer(),
    refill_interval_ms: non_neg_integer()
  }

  @doc false
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Acquires a token for the given rate limit bucket.

  Returns `:ok` if a token is available, or `{:error, :rate_limited}`
  if the bucket is empty.

  ## Parameters

    * `pid` — The RateLimiter process
    * `bucket` — `:spot`, `:futures`, or `:orders`
    * `weight` — How many tokens this request consumes (default: 1)
  """
  @spec acquire(pid() | atom(), atom(), non_neg_integer()) :: :ok | {:error, :rate_limited}
  def acquire(pid, bucket \\ :spot, weight \\ 1) do
    GenServer.call(pid, {:acquire, bucket, weight})
  end

  @doc """
  Waits for a token to become available, blocking the caller
  until the bucket has sufficient tokens.

  ## Parameters

    * `pid` — The RateLimiter process
    * `bucket` — `:spot`, `:futures`, or `:orders`
    * `weight` — How many tokens this request consumes (default: 1)
    * `timeout_ms` — Max wait time in milliseconds (default: 30_000)
  """
  @spec wait_and_acquire(pid() | atom(), atom(), non_neg_integer(), non_neg_integer()) ::
          :ok | {:error, :timeout}
  def wait_and_acquire(pid, bucket \\ :spot, weight \\ 1, timeout_ms \\ 30_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms

    case acquire(pid, bucket, weight) do
      :ok ->
        :ok

      {:error, :rate_limited} ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(50)
          wait_and_acquire(pid, bucket, weight, deadline - System.monotonic_time(:millisecond))
        else
          {:error, :timeout}
        end
    end
  end

  @doc """
  Returns the current token counts for all buckets.
  """
  @spec get_bucket_status(pid() | atom()) :: %{atom() => float()}
  def get_bucket_status(pid) do
    GenServer.call(pid, :get_status)
  end

  @doc """
  Updates the rate limit configuration at runtime.
  """
  @spec update_config(pid() | atom(), rate_limit_config()) :: :ok
  def update_config(pid, config) do
    GenServer.cast(pid, {:update_config, config})
  end

  @impl true
  def init(opts) do
    config = %{
      spot_rpm: Keyword.get(opts, :spot_rpm, @default_spot_rpm),
      futures_rpm: Keyword.get(opts, :futures_rpm, @default_futures_rpm),
      order_rps: Keyword.get(opts, :order_rps, @default_order_rps),
      refill_interval_ms: Keyword.get(opts, :refill_interval_ms, @refill_interval_ms)
    }

    table_name = Keyword.get(opts, :ets_table, :binance_rate_limiter)
    ets = :ets.new(table_name, [:named_table, :public, :set, read_concurrency: true, write_concurrency: true])

    now = System.monotonic_time(:millisecond)

    :ets.insert(ets, {:spot, %{tokens: config.spot_rpm, max: config.spot_rpm, last_refill: now}})
    :ets.insert(ets, {:futures, %{tokens: config.futures_rpm, max: config.futures_rpm, last_refill: now}})
    :ets.insert(ets, {:orders, %{tokens: config.order_rps, max: config.order_rps, last_refill: now}})

    schedule_refill(config.refill_interval_ms)

    state = %{
      ets: ets,
      config: config
    }

    Logger.info("[BinanceRateLimiter] Initialized with spot=#{config.spot_rpm}/min, futures=#{config.futures_rpm}/min, orders=#{config.order_rps}/s")

    {:ok, state}
  end

  @impl true
  def handle_call({:acquire, bucket, weight}, _from, state) do
    result =
      case refill_and_check(state.ets, bucket, weight, state.config) do
        true -> :ok
        false -> {:error, :rate_limited}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    refill_all(state.ets, state.config)

    status =
      [:spot, :futures, :orders]
      |> Enum.map(fn bucket ->
        [{^bucket, entry}] = :ets.lookup(state.ets, bucket)
        {bucket, entry.tokens}
      end)
      |> Map.new()

    {:reply, status, state}
  end

  @impl true
  def handle_cast({:update_config, new_config}, state) do
    merged = Map.merge(state.config, new_config)

    if new_config[:spot_rpm] do
      update_bucket_max(state.ets, :spot, new_config.spot_rpm)
    end

    if new_config[:futures_rpm] do
      update_bucket_max(state.ets, :futures, new_config.futures_rpm)
    end

    if new_config[:order_rps] do
      update_bucket_max(state.ets, :orders, new_config.order_rps)
    end

    Logger.info("[BinanceRateLimiter] Configuration updated: #{inspect(merged)}")
    {:noreply, %{state | config: merged}}
  end

  @impl true
  def handle_info(:refill, state) do
    refill_all(state.ets, state.config)
    schedule_refill(state.config.refill_interval_ms)
    {:noreply, state}
  end

  defp refill_and_check(ets, bucket, weight, config) do
    case :ets.lookup(ets, bucket) do
      [{^bucket, entry}] ->
        now = System.monotonic_time(:millisecond)
        elapsed = now - entry.last_refill

        max_tokens = entry.max
        refill_rate = refill_rate(bucket, config)

        new_tokens = min(max_tokens, entry.tokens + (elapsed * refill_rate / 1000))

        if new_tokens >= weight do
          :ets.insert(ets, {bucket, %{entry | tokens: new_tokens - weight, last_refill: now}})
          true
        else
          :ets.insert(ets, {bucket, %{entry | tokens: new_tokens, last_refill: now}})
          false
        end

      [] ->
        false
    end
  end

  defp refill_all(ets, config) do
    now = System.monotonic_time(:millisecond)

    Enum.each([:spot, :futures, :orders], fn bucket ->
      case :ets.lookup(ets, bucket) do
        [{^bucket, entry}] ->
          elapsed = now - entry.last_refill
          refill_rate = refill_rate(bucket, config)
          new_tokens = min(entry.max, entry.tokens + (elapsed * refill_rate / 1000))
          :ets.insert(ets, {bucket, %{entry | tokens: new_tokens, last_refill: now}})

        [] ->
          :ok
      end
    end)
  end

  defp refill_rate(:spot, config), do: config.spot_rpm / 60.0
  defp refill_rate(:futures, config), do: config.futures_rpm / 60.0
  defp refill_rate(:orders, config), do: config.order_rps

  defp update_bucket_max(ets, bucket, new_max) do
    case :ets.lookup(ets, bucket) do
      [{^bucket, entry}] ->
        capped_tokens = min(entry.tokens, new_max)
        :ets.insert(ets, {bucket, %{entry | max: new_max, tokens: capped_tokens}})

      [] ->
        :ok
    end
  end

  defp schedule_refill(interval_ms) do
    Process.send_after(self(), :refill, interval_ms)
  end
end
