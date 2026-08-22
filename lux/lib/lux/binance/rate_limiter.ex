defmodule Lux.Binance.RateLimiter do
  @moduledoc """
  Rate Limiter GenServer and Req middleware for Binance API limits.

  Tracks weight usage (`x-mbx-used-weight-1m`, `x-fapi-used-weight-1m`)
  and backoff windows triggered by 429 (Rate Limit Exceeded) or 418 (Teapot / Ban) status codes.
  """

  use GenServer
  require Logger

  @table :lux_binance_rate_limiter

  defstruct spot_weight: 0,
            futures_weight: 0,
            spot_backoff_until: 0,
            futures_backoff_until: 0

  # API

  @doc """
  Starts the RateLimiter GenServer.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Checks if the specified market type is currently rate limited.
  Returns `:ok` or `{:error, {:rate_limited, wait_ms}}`.
  """
  @spec check_rate_limit(atom()) :: :ok | {:error, {:rate_limited, integer()}}
  def check_rate_limit(market_type \\ :spot) do
    now = System.system_time(:millisecond)
    backoff_until = get_backoff_until(market_type)

    if now < backoff_until do
      {:error, {:rate_limited, backoff_until - now}}
    else
      :ok
    end
  end

  @doc """
  Records response status code and headers to update weight tracking and backoff state.
  """
  @spec record_response(list() | map(), integer(), atom()) :: :ok
  def record_response(headers, status_code, market_type \\ :spot) do
    headers_map = normalize_headers(headers)
    now = System.system_time(:millisecond)

    if status_code in [429, 418] do
      retry_after_sec = parse_header_int(headers_map, "retry-after", 60)
      backoff_until = now + retry_after_sec * 1000
      set_backoff_until(market_type, backoff_until)
      Logger.warning("Binance #{market_type} API rate limit hit (HTTP #{status_code}). Backoff until #{backoff_until} (#{retry_after_sec}s)")
    end

    weight_header =
      if market_type == :futures, do: "x-fapi-used-weight-1m", else: "x-mbx-used-weight-1m"

    if weight_str = Map.get(headers_map, weight_header) do
      case Integer.parse(weight_str) do
        {weight, _} -> set_used_weight(market_type, weight)
        :error -> :ok
      end
    end

    :ok
  end

  @doc """
  Gets the last recorded used weight for a market type.
  """
  @spec get_used_weight(atom()) :: integer()
  def get_used_weight(market_type \\ :spot) do
    key = weight_key(market_type)
    case get_ets_value(key, {0, 0}) do
      {weight, timestamp} ->
        now = System.system_time(:millisecond)
        if now - timestamp > 60_000 do
          0
        else
          weight
        end
      weight when is_integer(weight) ->
        weight
      _ ->
        0
    end
  end

  @doc """
  Gets the backoff_until timestamp (ms) for a market type.
  """
  @spec get_backoff_until(atom()) :: integer()
  def get_backoff_until(market_type \\ :spot) do
    key = backoff_key(market_type)
    get_ets_value(key, 0)
  end

  @doc """
  Resets the rate limiter state (useful for tests).
  """
  def reset do
    if ets_exists?() do
      :ets.insert(@table, {:spot_weight, {0, 0}})
      :ets.insert(@table, {:futures_weight, {0, 0}})
      :ets.insert(@table, {:spot_backoff_until, 0})
      :ets.insert(@table, {:futures_backoff_until, 0})
    end
    :ok
  end

  @doc """
  Blocks the current process until the rate limit backoff expires.
  """
  def wait_if_rate_limited(market_type \\ :spot) do
    now = System.system_time(:millisecond)
    backoff_until = get_backoff_until(market_type)
    wait_ms = backoff_until - now

    weight_wait_ms = check_weight_limit(market_type)
    total_wait_ms = max(wait_ms, weight_wait_ms)

    if total_wait_ms > 0 do
      if weight_wait_ms > wait_ms do
        Logger.warning("Binance #{market_type} API weight limit approached. Preemptively backing off for #{weight_wait_ms}ms.")
      end
      Process.sleep(total_wait_ms)
      wait_if_rate_limited(market_type)
    else
      :ok
    end
  end

  defp check_weight_limit(market_type) do
    now = System.system_time(:millisecond)
    key = weight_key(market_type)
    threshold = if market_type == :futures, do: 2300, else: 5900
    
    case get_ets_value(key, {0, 0}) do
      {weight, timestamp} when weight >= threshold ->
        elapsed = now - timestamp
        if elapsed < 60_000 do
          60_000 - elapsed
        else
          0
        end
      _ ->
        0
    end
  end

  @doc """
  Records a 429/418 response to set the global backoff.
  """
  def record_rate_limit(headers, status_code, market_type \\ :spot) do
    record_response(headers, status_code, market_type)
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    create_table_if_not_exists()
    {:ok, %__MODULE__{}}
  end

  # Helper functions for ETS operations

  defp create_table_if_not_exists do
    unless ets_exists?() do
      :ets.new(@table, [:set, :public, :named_table, read_concurrency: true, write_concurrency: true])
      :ets.insert(@table, {:spot_weight, {0, 0}})
      :ets.insert(@table, {:futures_weight, {0, 0}})
      :ets.insert(@table, {:spot_backoff_until, 0})
      :ets.insert(@table, {:futures_backoff_until, 0})
    end
  end

  defp ets_exists? do
    :ets.whereis(@table) != :undefined
  end

  defp get_ets_value(key, default) do
    create_table_if_not_exists()
    case :ets.lookup(@table, key) do
      [{^key, val}] -> val
      [] -> default
    end
  rescue
    _ -> default
  end

  defp set_backoff_until(market_type, timestamp) do
    create_table_if_not_exists()
    :ets.insert(@table, {backoff_key(market_type), timestamp})
  end

  defp set_used_weight(market_type, weight) do
    create_table_if_not_exists()
    now = System.system_time(:millisecond)
    :ets.insert(@table, {weight_key(market_type), {weight, now}})
  end

  defp weight_key(:futures), do: :futures_weight
  defp weight_key(_), do: :spot_weight

  defp backoff_key(:futures), do: :futures_backoff_until
  defp backoff_key(_), do: :spot_backoff_until

  defp normalize_headers(headers) when is_map(headers) do
    headers
    |> Enum.map(fn {k, v} -> {String.downcase(to_string(k)), to_string(v)} end)
    |> Map.new()
  end

  defp normalize_headers(headers) when is_list(headers) do
    headers
    |> Enum.map(fn {k, v} ->
      val = if is_list(v), do: Enum.join(v, ", "), else: to_string(v)
      {String.downcase(to_string(k)), val}
    end)
    |> Map.new()
  end

  defp parse_header_int(headers_map, header_name, default) do
    case Map.get(headers_map, header_name) do
      nil -> default
      val ->
        case Integer.parse(to_string(val)) do
          {int_val, _} -> int_val
          :error -> default
        end
    end
  end
end
