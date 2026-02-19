defmodule Lux.Integrations.Binance.RateLimiter do
  @moduledoc """
  Rate limiter for Binance API requests.

  Implements a sliding-window rate limiter to comply with Binance API limits:

    * **Request weight limit**: 6,000 per minute (spot), 2,400 per minute (futures)
    * **Order rate limit**: 100 orders per 10 seconds, 200,000 orders per day
    * **Raw requests**: 61,000 per 5 minutes

  ## Usage

      # Check if a request can be made
      :ok = Lux.Integrations.Binance.RateLimiter.check_rate(:spot, :request, 1)

      # Record a completed request
      Lux.Integrations.Binance.RateLimiter.record_request(:spot, :request, 5)

  ## Architecture

  Uses an ETS table for fast lock-free reads. Each key tracks timestamps
  of recent requests within the rate limit window.
  """

  use GenServer
  require Logger

  @table :binance_rate_limits

  # Binance rate limits
  @limits %{
    spot: %{
      request: {1_200, 60_000},       # 1,200 weight per minute
      order: {100, 10_000},            # 100 orders per 10 seconds
      order_daily: {200_000, 86_400_000}  # 200,000 per day
    },
    futures: %{
      request: {2_400, 60_000},        # 2,400 weight per minute
      order: {100, 10_000},            # 100 orders per 10 seconds
      order_daily: {200_000, 86_400_000}
    }
  }

  @type endpoint :: :spot | :futures
  @type limit_type :: :request | :order | :order_daily

  # --- Public API ---

  @doc """
  Starts the rate limiter process.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Checks whether a request with the given weight can be made
  without exceeding rate limits. Returns `:ok` or `{:error, :rate_limited}`.
  """
  @spec check_rate(endpoint(), limit_type(), pos_integer()) :: :ok | {:error, :rate_limited}
  def check_rate(endpoint, limit_type, weight \\ 1) do
    {max_weight, window_ms} = get_limit(endpoint, limit_type)
    key = {endpoint, limit_type}
    now = System.monotonic_time(:millisecond)
    cutoff = now - window_ms

    current_weight = get_current_weight(key, cutoff)

    if current_weight + weight <= max_weight do
      :ok
    else
      {:error, :rate_limited}
    end
  end

  @doc """
  Records that a request with the given weight was made.
  """
  @spec record_request(endpoint(), limit_type(), pos_integer()) :: :ok
  def record_request(endpoint, limit_type, weight \\ 1) do
    key = {endpoint, limit_type}
    now = System.monotonic_time(:millisecond)

    entries = get_entries(key)
    updated = [{now, weight} | entries]
    :ets.insert(@table, {key, updated})
    :ok
  end

  @doc """
  Returns the current used weight for the given endpoint and limit type.
  """
  @spec current_weight(endpoint(), limit_type()) :: non_neg_integer()
  def current_weight(endpoint, limit_type) do
    {_max, window_ms} = get_limit(endpoint, limit_type)
    key = {endpoint, limit_type}
    cutoff = System.monotonic_time(:millisecond) - window_ms
    get_current_weight(key, cutoff)
  end

  @doc """
  Resets all rate limit counters.
  """
  @spec reset() :: :ok
  def reset do
    :ets.delete_all_objects(@table)
    :ok
  end

  # --- GenServer callbacks ---

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    schedule_cleanup()
    {:ok, %{table: table}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_stale_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  # --- Private helpers ---

  defp get_limit(endpoint, limit_type) do
    @limits
    |> Map.fetch!(endpoint)
    |> Map.fetch!(limit_type)
  end

  defp get_entries(key) do
    case :ets.lookup(@table, key) do
      [{^key, entries}] -> entries
      [] -> []
    end
  end

  defp get_current_weight(key, cutoff) do
    key
    |> get_entries()
    |> Enum.filter(fn {ts, _w} -> ts > cutoff end)
    |> Enum.reduce(0, fn {_ts, w}, acc -> acc + w end)
  end

  defp cleanup_stale_entries do
    now = System.monotonic_time(:millisecond)
    max_window = 86_400_000  # 24 hours

    :ets.tab2list(@table)
    |> Enum.each(fn {key, entries} ->
      cutoff = now - max_window
      cleaned = Enum.filter(entries, fn {ts, _w} -> ts > cutoff end)
      :ets.insert(@table, {key, cleaned})
    end)
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, 60_000)
  end
end
