defmodule Lux.LLM.FallbackChain do
  @moduledoc """
  Resilient LLM request handling with configurable provider fallback chains.

  Tries providers in order, respecting circuit breaker state, until one succeeds
  or all are exhausted.

  ## Usage

      chain = [:openai, :anthropic, :local]
      opts  = %{prompt: "Hello", tools: [], config: %{}}

      case Lux.LLM.FallbackChain.call(chain, opts) do
        {:ok, response}          -> response
        {:error, :all_failed, _} -> handle_error()
      end

  """

  require Logger

  alias Lux.LLM.CircuitBreaker
  alias Lux.LLM.Registry

  @type provider_name :: atom()
  @type chain :: [provider_name()]
  @type call_opts :: %{
          prompt: String.t(),
          tools: list(),
          config: map()
        }
  @type failure_log :: [{provider_name(), term()}]

  @doc """
  Executes the request against the chain, trying each provider in order.

  Returns `{:ok, response}` on first success, or
  `{:error, :all_failed, failure_log}` when every provider fails.
  """
  @spec call(chain(), call_opts(), GenServer.server()) ::
          {:ok, term()} | {:error, :all_failed, failure_log()}
  def call(chain, opts, circuit_breaker \\ CircuitBreaker) do
    do_call(chain, opts, circuit_breaker, [])
  end

  defp do_call([], _opts, _cb, failures) do
    {:error, :all_failed, Enum.reverse(failures)}
  end

  defp do_call([provider | rest], opts, cb, failures) do
    if CircuitBreaker.allow_request?(provider, cb) do
      case dispatch(provider, opts) do
        {:ok, response} ->
          CircuitBreaker.record_success(provider, cb)
          {:ok, response}

        {:error, reason} ->
          Logger.warning("[FallbackChain] Provider #{provider} failed: #{inspect(reason)}")
          CircuitBreaker.record_failure(provider, cb)
          do_call(rest, opts, cb, [{provider, reason} | failures])
      end
    else
      Logger.info("[FallbackChain] Provider #{provider} skipped (circuit open)")
      do_call(rest, opts, cb, [{provider, :circuit_open} | failures])
    end
  end

  defp dispatch(provider, %{prompt: prompt, tools: tools, config: config}) do
    case Registry.lookup(provider) do
      {:ok, %{module: module}} when not is_nil(module) ->
        module.call(prompt, tools, config)

      {:ok, _} ->
        {:error, :no_module_registered}

      {:error, :not_found} ->
        {:error, {:provider_not_registered, provider}}
    end
  end
end
