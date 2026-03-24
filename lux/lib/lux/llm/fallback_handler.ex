defmodule Lux.LLM.FallbackHandler do
  @moduledoc """
  Handles fallback logic when LLM providers fail.

  Implements intelligent fallback strategies:
  - Retry with exponential backoff
  - Failover to alternative providers
  - Circuit breaker pattern for failing providers

  ## Features

  - Automatic retry with configurable backoff
  - Provider failover based on priority
  - Circuit breaker to prevent cascading failures
  - Detailed error logging and tracking

  ## Usage

      # Execute with automatic fallback
      {:ok, response} = FallbackHandler.execute(
        "Hello!",
        [],
        [{:openai, "gpt-4"}, {:anthropic, "claude-3-opus"}],
        %{max_retries: 3}
      )

  """

  alias Lux.LLM.ProviderRegistry
  alias Lux.LLM.PerformanceMonitor

  require Logger

  @type provider_chain :: [{atom(), String.t() | nil}]
  @type execution_result :: {:ok, map()} | {:error, term()}

  @circuit_breaker_threshold 5
  @circuit_breaker_timeout_ms 60_000

  @doc """
  Execute a request with automatic fallback.

  ## Options

    * `:max_retries` - Maximum retries per provider (default: 2)
    * `:retry_delay_ms` - Initial retry delay (default: 1000)
    * `:timeout` - Request timeout (default: 60000)

  ## Examples

      iex> FallbackHandler.execute("Hello!", [], [{:openai, "gpt-4"}], %{})
      {:ok, %Lux.LLM.Response{...}}

  """
  @spec execute(String.t(), list(), provider_chain(), map()) :: execution_result()
  def execute(prompt, tools, provider_chain, opts \\ %{}) do
    opts = Map.merge(default_opts(), opts)

    execute_chain(prompt, tools, provider_chain, opts, [])
  end

  @doc """
  Get fallback providers for a given provider.

  ## Options

    * `:all` - Return all other providers
    * `:same_tier` - Return providers in same cost tier
    * `none` - No fallback

  ## Examples

      iex> FallbackHandler.get_fallbacks(:openai, :all)
      [{:anthropic, nil}, {:together_ai, nil}]

  """
  @spec get_fallbacks(atom(), atom()) :: provider_chain()
  def get_fallbacks(provider, strategy \\ :all) do
    case strategy do
      :none -> []
      :all ->
        ProviderRegistry.list_enabled()
        |> Enum.reject(fn p -> p == provider end)
        |> Enum.map(fn p -> {p, nil} end)
      :same_tier ->
        get_same_tier_fallbacks(provider)
    end
  end

  # Private functions

  defp default_opts do
    %{
      max_retries: 2,
      retry_delay_ms: 1000,
      timeout: 60_000
    }
  end

  defp execute_chain(_prompt, _tools, [], _opts, errors) do
    {:error, {:all_providers_failed, Enum.reverse(errors)}}
  end

  defp execute_chain(prompt, tools, [{provider, model} | rest], opts, errors) do
    if circuit_breaker_open?(provider) do
      Logger.warning("Circuit breaker open for #{provider}, skipping")
      execute_chain(prompt, tools, rest, opts, [{provider, :circuit_breaker_open} | errors])
    else
      case execute_with_retry(provider, model, prompt, tools, opts) do
        {:ok, response} ->
          record_success(provider)
          {:ok, response}

        {:error, reason} ->
          record_failure(provider)
          Logger.warning("Provider #{provider} failed: #{inspect(reason)}")
          execute_chain(prompt, tools, rest, opts, [{provider, reason} | errors])
      end
    end
  end

  defp execute_with_retry(provider, model, prompt, tools, opts) do
    max_retries = Map.get(opts, :max_retries, 2)
    retry_delay_ms = Map.get(opts, :retry_delay_ms, 1000)

    do_execute_with_retry(provider, model, prompt, tools, opts, max_retries, retry_delay_ms)
  end

  defp do_execute_with_retry(_provider, _model, _prompt, _tools, _opts, 0, _delay) do
    {:error, :max_retries_exceeded}
  end

  defp do_execute_with_retry(provider, model, prompt, tools, opts, retries_left, delay) do
    config = ProviderRegistry.get_config(provider)
    module = Map.get(config, :module)

    if is_nil(module) do
      {:error, {:invalid_provider, provider}}
    else
      model = model || get_default_model(config)
      call_config = build_call_config(model, config, opts)

      start_time = System.monotonic_time(:millisecond)

      result = try do
        module.call(prompt, tools, call_config)
      rescue
        e -> {:error, {:exception, e}}
      catch
        kind, reason -> {:error, {kind, reason}}
      end

      end_time = System.monotonic_time(:millisecond)
      latency = end_time - start_time

      case result do
        {:ok, response} ->
          PerformanceMonitor.record_request(provider, latency, :success)
          {:ok, response}

        {:error, reason} when retries_left > 0 ->
          Logger.debug("Retrying #{provider} after #{delay}ms, #{retries_left - 1} retries left")
          Process.sleep(delay)
          new_delay = min(delay * 2, 30_000)
          do_execute_with_retry(provider, model, prompt, tools, opts, retries_left - 1, new_delay)

        {:error, reason} ->
          PerformanceMonitor.record_request(provider, latency, :failure)
          {:error, reason}
      end
    end
  end

  defp get_default_model(config) do
    config
    |> Map.get(:models, [])
    |> List.first()
  end

  defp build_call_config(model, _provider_config, opts) do
    %{
      model: model,
      timeout: Map.get(opts, :timeout, 60_000)
    }
  end

  defp circuit_breaker_open?(provider) do
    # Check if the circuit breaker should be open
    stats = PerformanceMonitor.get_stats(provider)

    case Map.get(stats, :consecutive_failures, 0) do
      failures when failures >= @circuit_breaker_threshold ->
        # Check if timeout has passed
        last_failure = Map.get(stats, :last_failure_time)
        case last_failure do
          nil -> true
          time ->
            elapsed = System.monotonic_time(:millisecond) - time
            elapsed < @circuit_breaker_timeout_ms
        end
      _ -> false
    end
  end

  defp record_success(provider) do
    PerformanceMonitor.reset_consecutive_failures(provider)
  end

  defp record_failure(provider) do
    PerformanceMonitor.increment_consecutive_failures(provider)
  end

  defp get_same_tier_fallbacks(provider) do
    tier = get_provider_tier(provider)

    ProviderRegistry.list_enabled()
    |> Enum.reject(fn p -> p == provider end)
    |> Enum.filter(fn p -> get_provider_tier(p) == tier end)
    |> Enum.map(fn p -> {p, nil} end)
  end

  defp get_provider_tier(:openai), do: 1
  defp get_provider_tier(:anthropic), do: 1
  defp get_provider_tier(:together_ai), do: 2
  defp get_provider_tier(_), do: 3
end