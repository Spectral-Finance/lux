defmodule Lux.LLM.FallbackChain do
  @moduledoc """
  Intelligent fallback handling for LLM provider failures.

  When an LLM call fails, the FallbackChain automatically retries with
  alternative providers based on a configurable chain. It supports:

  - **Explicit chains** — Define a specific fallback order
  - **Auto-fallback** — Automatically tries healthy providers in order
  - **Retry with backoff** — Retry the same provider with exponential backoff
  - **Circuit breaking** — Skip providers with too many consecutive errors

  ## Usage

      # Define a fallback chain
      chain = Lux.LLM.FallbackChain.new([
        {:openai, %{model: "gpt-4o"}},
        {:anthropic, %{model: "claude-3-5-sonnet-20241022"}},
        {:together_ai, %{model: "mistralai/Mistral-7B-Instruct-v0.2"}}
      ])

      # Execute with fallback
      {:ok, response, provider_used} = Lux.LLM.FallbackChain.call(chain, prompt, tools, config)

      # Auto-fallback using registry health data
      {:ok, response, provider_used} = Lux.LLM.FallbackChain.auto_call(prompt, tools, config)
  """

  alias Lux.LLM.Registry

  require Logger

  @type provider_config :: {atom(), map()}
  @type chain :: [provider_config()]

  defstruct providers: [],
            max_retries: 1,
            base_backoff_ms: 100,
            circuit_breaker_threshold: 5

  @doc """
  Creates a new fallback chain from a list of `{provider_name, config}` tuples.

  ## Options

  - `:max_retries` - Retries per provider before moving to next (default: 1)
  - `:base_backoff_ms` - Base backoff for retries in ms (default: 100)
  - `:circuit_breaker_threshold` - Skip provider after N consecutive errors (default: 5)
  """
  @spec new(chain(), keyword()) :: %__MODULE__{}
  def new(providers, opts \\ []) do
    %__MODULE__{
      providers: providers,
      max_retries: Keyword.get(opts, :max_retries, 1),
      base_backoff_ms: Keyword.get(opts, :base_backoff_ms, 100),
      circuit_breaker_threshold: Keyword.get(opts, :circuit_breaker_threshold, 5)
    }
  end

  @doc """
  Executes an LLM call through the fallback chain.

  Tries each provider in order. On failure, moves to the next provider.
  Returns `{:ok, response, provider_name}` on success, or
  `{:error, errors}` if all providers fail.
  """
  @spec call(%__MODULE__{}, String.t(), list(), map()) ::
          {:ok, term(), atom()} | {:error, [{atom(), term()}]}
  def call(%__MODULE__{} = chain, prompt, tools, base_config) do
    errors =
      Enum.reduce_while(chain.providers, [], fn {provider_name, provider_config}, errors ->
        if circuit_open?(provider_name, chain.circuit_breaker_threshold) do
          Logger.debug("Circuit open for #{provider_name}, skipping")
          {:cont, [{provider_name, :circuit_open} | errors]}
        else
          merged_config = Map.merge(base_config, provider_config)

          case try_provider(provider_name, prompt, tools, merged_config, chain) do
            {:ok, response} ->
              {:halt, {:ok, response, provider_name}}

            {:error, reason} ->
              Logger.warning(
                "LLM fallback: #{provider_name} failed with #{inspect(reason)}, trying next"
              )

              {:cont, [{provider_name, reason} | errors]}
          end
        end
      end)

    case errors do
      {:ok, response, provider} -> {:ok, response, provider}
      error_list when is_list(error_list) -> {:error, Enum.reverse(error_list)}
    end
  end

  @doc """
  Automatically builds a fallback chain from the registry (sorted by health)
  and executes the call.

  This is the simplest way to get automatic fallback — no explicit chain needed.
  """
  @spec auto_call(String.t(), list(), map(), keyword()) ::
          {:ok, term(), atom()} | {:error, [{atom(), term()}]}
  def auto_call(prompt, tools, config, opts \\ []) do
    providers =
      Registry.healthy_providers()
      |> Enum.map(fn {name, _module, _score} ->
        {name, %{}}
      end)

    chain = new(providers, opts)
    call(chain, prompt, tools, config)
  end

  # ── Private ─────────────────────────────────────────────────────────

  defp try_provider(provider_name, prompt, tools, config, chain) do
    with {:ok, module} <- Registry.get(provider_name) do
      do_retries(
        module,
        provider_name,
        prompt,
        tools,
        config,
        chain.max_retries,
        chain.base_backoff_ms,
        0
      )
    else
      :error -> {:error, :provider_not_found}
    end
  end

  defp do_retries(
         module,
         provider_name,
         prompt,
         tools,
         config,
         max_retries,
         base_backoff,
         attempt
       ) do
    start_time = System.monotonic_time(:millisecond)

    case module.call(prompt, tools, config) do
      {:ok, _} = success ->
        latency = System.monotonic_time(:millisecond) - start_time
        Registry.report_health(provider_name, :ok, latency)
        success

      {:error, _reason} = error ->
        latency = System.monotonic_time(:millisecond) - start_time
        Registry.report_health(provider_name, :error, latency)

        if attempt < max_retries do
          backoff = base_backoff * :math.pow(2, attempt) |> round()
          Process.sleep(backoff)

          do_retries(
            module,
            provider_name,
            prompt,
            tools,
            config,
            max_retries,
            base_backoff,
            attempt + 1
          )
        else
          error
        end
    end
  end

  defp circuit_open?(provider_name, threshold) do
    case Registry.health(provider_name) do
      %{consecutive_errors: n} when n >= threshold -> true
      _ -> false
    end
  end
end
