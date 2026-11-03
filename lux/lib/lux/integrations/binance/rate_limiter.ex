defmodule Lux.Integrations.Binance.RateLimiter do
  @moduledoc """
  Rate limiting tracker and backoff controller for Binance API calls.
  Enforces IP weight limits and order rate limits with exponential backoff on 429/418 responses.
  """

  @max_ip_weight_per_min 1200
  @max_orders_per_sec 10

  @type state :: %{
          used_ip_weight: non_neg_integer(),
          orders_in_window: non_neg_integer(),
          window_start: non_neg_integer(),
          backoff_until: non_neg_integer()
        }

  @doc """
  Initializes a new rate limiter state.
  """
  @spec init() :: state()
  def init do
    %{
      used_ip_weight: 0,
      orders_in_window: 0,
      window_start: :os.system_time(:second),
      backoff_until: 0
    }
  end

  @doc """
  Checks if a request with given weight can be performed immediately.
  """
  @spec can_request?(state(), pos_integer(), boolean()) :: {:ok, state()} | {:error, :rate_limited, non_neg_integer()}
  def can_request?(state, weight \\ 1, is_order \\ false) do
    now = :os.system_time(:second)

    # Check active backoff penalty
    if now < state.backoff_until do
      retry_after = state.backoff_until - now
      {:error, :rate_limited, retry_after}
    else
      # Reset 1-minute window if expired
      state =
        if now - state.window_start >= 60 do
          %{state | used_ip_weight: 0, orders_in_window: 0, window_start: now}
        else
          state
        end

      cond do
        state.used_ip_weight + weight > @max_ip_weight_per_min ->
          remaining_window = 60 - (now - state.window_start)
          {:error, :rate_limited, max(remaining_window, 1)}

        is_order and state.orders_in_window >= @max_orders_per_sec ->
          {:error, :rate_limited, 1}

        true ->
          updated_state = %{
            state
            | used_ip_weight: state.used_ip_weight + weight,
              orders_in_window: if(is_order, do: state.orders_in_window + 1, else: state.orders_in_window)
          }

          {:ok, updated_state}
      end
    end
  end

  @doc """
  Applies backoff penalties when receiving HTTP 429 (Too Many Requests) or HTTP 418 (IP Ban).
  """
  @spec handle_rate_limit_response(state(), pos_integer(), non_neg_integer()) :: state()
  def handle_rate_limit_response(state, status_code, retry_after_sec \\ 60) do
    now = :os.system_time(:second)

    penalty =
      case status_code do
        418 -> max(retry_after_sec, 300) # 5 min IP ban minimum
        429 -> max(retry_after_sec, 60)  # 1 min default for 429
        _ -> retry_after_sec
      end

    %{state | backoff_until: now + penalty}
  end
end
