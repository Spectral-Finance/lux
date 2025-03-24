defmodule Lux.Integration.Etherscan.RateLimitedAPI do
  @moduledoc """
  Wrapper module for making rate-limited Etherscan API calls.

  This module provides functions to make API calls that respect Etherscan's rate limits.

  Etherscan API has rate limits:
  - 5 calls per second for most endpoints
  - 2 calls per second for some Pro endpoints
  """

  @doc """
  Throttles standard Etherscan API calls (5 calls per second).
  Waits if necessary to avoid hitting the rate limit.
  """
  def throttle_standard_api(ctx \\ %{}) do
    retries = Map.get(ctx, :retries, 0)

    case RateLimiter.hit("etherscan_standard_api", 1_200, 5) do
      {:allow, _count} ->
        :ok
      {:deny, _limit} ->
        backoff = 100 + :rand.uniform(1000)
        Process.sleep(round(backoff))
        throttle_standard_api(Map.put(ctx, :retries, retries + 1))
    end
  end

  @doc """
  Throttles Etherscan Pro API calls (2 calls per second).
  Waits if necessary to avoid hitting the rate limit.
  """
  def throttle_pro_api(ctx \\ %{}) do
    retries = Map.get(ctx, :retries, 0)

    case RateLimiter.hit("etherscan_pro_api", 1_000, 2) do
      {:allow, _count} ->
        :ok
      {:deny, _limit} ->
        backoff = 100 + :rand.uniform(1000)
        Process.sleep(round(backoff))
        throttle_pro_api(Map.put(ctx, :retries, retries + 1))
    end
  end

  @doc """
  Executes a function with rate limiting.
  This is useful for wrapping API calls to ensure they respect rate limits.
  """
  def with_rate_limit(api_type, fun) when api_type in [:standard, :pro] do
    case api_type do
      :standard -> throttle_standard_api()
      :pro -> throttle_pro_api()
    end

    fun.()
  end

  @doc """
  Makes a rate-limited API call to Etherscan.

  ## Parameters

  - `api_type`: Either `:standard` (5 calls/sec) or `:pro` (2 calls/sec)
  - `module`: The API module to call (e.g., `Lux.Lenses.Etherscan.Balance`)
  - `function`: The function to call (e.g., `:focus`)
  - `args`: The arguments to pass to the function

  ## Examples

      RateLimitedAPI.call(:standard, Lux.Lenses.Etherscan.Balance, :focus, [%{address: "0x123", chainid: 1}])
  """
  def call(api_type, module, function, args) when api_type in [:standard, :pro] do
    with_rate_limit(api_type, fn ->
      apply(module, function, args)
    end)
  end

  @doc """
  Makes a rate-limited API call to a standard Etherscan endpoint (5 calls/sec).
  """
  def call_standard(module, function, args) do
    call(:standard, module, function, args)
  end

  @doc """
  Makes a rate-limited API call to a pro Etherscan endpoint (2 calls/sec).
  """
  def call_pro(module, function, args) do
    call(:pro, module, function, args)
  end
end
