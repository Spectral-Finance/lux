defmodule Lux.Integrations.Twitter.RateLimiter do
  @moduledoc """
  Rate limit tracking for Twitter API v2 endpoints.

  Twitter API v2 rate limits vary by endpoint:
  - Tweets: 300 req/15min per user auth, 50 req/15min per app auth
  - Search: 450 req/15min per user auth, 100 req/15min per app auth
  - Users: 200 req/15min per user auth
  - Media: 25 req/15min per user auth
  """

  use Agent

  @endpoint_limits %{
    "tweets" => %{per_15min: 300, per_app: 50},
    "search" => %{per_15min: 450, per_app: 100},
    "users" => %{per_15min: 200, per_app: 100},
    "media" => %{per_15min: 25, per_app: 15}
  }

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc """
  Records an API call for rate limit tracking.
  """
  def record_call(endpoint) do
    now = DateTime.utc_now()
    Agent.update(__MODULE__, fn state ->
      calls = Map.get(state, endpoint, [])
      # Keep only calls from the last 15 minutes
      recent = Enum.filter(calls, fn ts ->
        DateTime.diff(now, ts, :minute) < 15
      end)
      Map.put(state, endpoint, [now | recent])
    end)
  end

  @doc """
  Checks if an endpoint is rate limited.
  Returns {:ok} or {:error, :rate_limited}.
  """
  def check_rate_limit(endpoint) do
    limits = Map.get(@endpoint_limits, endpoint, %{per_15min: 50})
    calls = Agent.get(__MODULE__, fn state -> Map.get(state, endpoint, []) end)
    limit = limits.per_15min

    if length(calls) >= limit do
      {:error, :rate_limited}
    else
      {:ok, limit - length(calls)}
    end
  end

  @doc """
  Parses rate limit headers from an API response.
  """
  def parse_headers(headers) do
    %{
      remaining: get_header_value(headers, "x-rate-limit-remaining"),
      limit: get_header_value(headers, "x-rate-limit-limit"),
      reset_at: get_header_value(headers, "x-rate-limit-reset")
    }
  end

  defp get_header_value(headers, key) do
    Enum.find_value(headers, fn {k, v} ->
      if String.downcase(k) == key, do: v
    end)
  end
end
