defmodule Lux.Integrations.Coinbase.RateLimiter do
  @moduledoc """
  Rate limiting tracker and backoff manager for Coinbase Advanced Trade API.
  Enforces per-second request limits and applies backoff when receiving HTTP 429.
  """

  @default_requests_per_sec 30
  @orders_per_sec 100

  @type state :: %{
          req_count: non_neg_integer(),
          current_second: non_neg_integer(),
          backoff_until: non_neg_integer()
        }

  @doc """
  Initializes a new Coinbase rate limiter state.
  """
  @spec init() :: state()
  def init do
    %{
      req_count: 0,
      current_second: :os.system_time(:second),
      backoff_until: 0
    }
  end

  @doc """
  Checks if a request can proceed within the rate limit.
  """
  @spec can_request?(state(), boolean()) :: {:ok, state()} | {:error, :rate_limited, non_neg_integer()}
  def can_request?(state, is_order \\ false) do
    now = :os.system_time(:second)

    if now < state.backoff_until do
      retry_after = state.backoff_until - now
      {:error, :rate_limited, retry_after}
    else
      limit = if is_order, do: @orders_per_sec, else: @default_requests_per_sec

      state =
        if now > state.current_second do
          %{state | req_count: 0, current_second: now}
        else
          state
        end

      if state.req_count >= limit do
        {:error, :rate_limited, 1}
      else
        {:ok, %{state | req_count: state.req_count + 1}}
      end
    end
  end

  @doc """
  Applies backoff penalty on receiving HTTP 429 Too Many Requests.
  """
  @spec handle_rate_limit(state(), non_neg_integer()) :: state()
  def handle_rate_limit(state, retry_after_sec \\ 5) do
    now = :os.system_time(:second)
    %{state | backoff_until: now + max(retry_after_sec, 2)}
  end
end
