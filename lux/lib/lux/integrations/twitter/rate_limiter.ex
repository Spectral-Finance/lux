defmodule Lux.Integrations.Twitter.RateLimiter do
  @moduledoc """
  Rate limit tracking and throttling for Twitter API v2.
  Tracks remaining request quotas from response headers, calculates
  exponential backoff with jitter on 429 Too Many Requests, and prevents
  unnecessary API calls when quotas are exhausted.
  """

  @type route_limit :: %{
          limit: non_neg_integer(),
          remaining: non_neg_integer(),
          reset_at: non_neg_integer(), # UNIX epoch timestamp
          updated_at: non_neg_integer()
        }

  @type state :: %{
          routes: %{String.t() => route_limit()}
        }

  @doc """
  Initializes an empty rate limiter state.
  """
  @spec init_state() :: state()
  def init_state do
    %{routes: %{}}
  end

  @doc """
  Checks if a request to the given endpoint can proceed based on cached rate limit state.
  Returns `:ok` or `{:wait_until, reset_timestamp}`.
  """
  @spec check_quota(state(), String.t(), non_neg_integer()) :: :ok | {:wait_until, non_neg_integer()}
  def check_quota(state, endpoint, current_time \\ :os.system_time(:second)) do
    case Map.get(state.routes, endpoint) do
      nil ->
        :ok

      %{remaining: 0, reset_at: reset_at} when reset_at > current_time ->
        {:wait_until, reset_at}

      _ ->
        :ok
    end
  end

  @doc """
  Updates rate limit tracking state based on HTTP response headers.
  """
  @spec update_from_headers(state(), String.t(), list({String.t(), String.t()}), non_neg_integer()) :: state()
  def update_from_headers(state, endpoint, headers, current_time \\ :os.system_time(:second)) do
    limit_info =
      headers
      |> Enum.reduce(%{}, fn {k, v}, acc ->
        case String.downcase(to_string(k)) do
          "x-rate-limit-limit" -> Map.put(acc, :limit, parse_int(v))
          "x-rate-limit-remaining" -> Map.put(acc, :remaining, parse_int(v))
          "x-rate-limit-reset" -> Map.put(acc, :reset_at, parse_int(v))
          _ -> acc
        end
      end)

    if Map.has_key?(limit_info, :remaining) and Map.has_key?(limit_info, :reset_at) do
      updated_entry =
        Map.merge(
          %{
            limit: Map.get(limit_info, :limit, 0),
            remaining: limit_info.remaining,
            reset_at: limit_info.reset_at,
            updated_at: current_time
          },
          limit_info
        )

      %{state | routes: Map.put(state.routes, endpoint, updated_entry)}
    else
      state
    end
  end

  @doc """
  Calculates exponential backoff delay in milliseconds with random jitter.
  """
  @spec calculate_backoff(non_neg_integer(), non_neg_integer() | nil, non_neg_integer()) :: non_neg_integer()
  def calculate_backoff(attempt, reset_at \\ nil, current_time \\ :os.system_time(:second)) do
    if reset_at && reset_at > current_time do
      # If explicit reset header is available, sleep until reset + 1s safety jitter
      delay_sec = max(reset_at - current_time + 1, 1)
      delay_sec * 1000
    else
      # Exponential backoff: base 1000ms * 2^(attempt) + uniform jitter (up to 500ms)
      base_delay = 1000 * :math.pow(2, min(attempt, 6)) |> round()
      jitter = :rand.uniform(500)
      base_delay + jitter
    end
  end

  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> 0
    end
  end
  defp parse_int(_), do: 0
end
