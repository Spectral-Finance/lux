defmodule Lux.LLM do
  @moduledoc """
  A module for interacting with LLMs. Provides a universal interface for
  multiple LLM providers with automatic routing, fallback handling,
  cost tracking, and performance monitoring.

  ## Usage

      # Basic call (uses default provider)
      {:ok, response} = Lux.LLM.call("Hello!", [], %{model: "gpt-4o"})

      # Call a specific provider
      {:ok, response} = Lux.LLM.call("Hello!", [], %{
        provider: :anthropic,
        model: "claude-3-5-sonnet-20241022",
        api_key: "sk-ant-..."
      })

      # Call with automatic fallback
      {:ok, response, provider_used} = Lux.LLM.call_with_fallback("Hello!", [], %{
        fallback_chain: [
          {:openai, %{model: "gpt-4o"}},
          {:anthropic, %{model: "claude-3-5-sonnet-20241022"}}
        ]
      })
  """

  alias Lux.LLM.{CostTracker, FallbackChain, PerformanceMonitor, Registry}

  require Logger

  defmodule Response do
    @moduledoc """
      A response from an LLM.
    """

    @type t :: %__MODULE__{
            content: String.t() | nil,
            tool_calls: [%{type: String.t(), name: String.t(), params: map()}],
            finish_reason: String.t() | nil,
            structured_output: map() | nil
          }

    defstruct content: nil,
              tool_calls: [],
              finish_reason: nil,
              structured_output: nil
  end

  @type prompt :: String.t()
  @type tools :: [Lux.Prism.t() | Lux.Beam.t() | Lux.Lens.t()]
  @type options :: map() | keyword()

  @callback call(prompt(), tools(), options()) :: {:ok, Response.t()} | {:error, String.t()}

  @default_module Application.compile_env(:lux, [Lux.LLM, :default_module], Lux.LLM.OpenAI)

  @doc """
  Calls an LLM provider with the given prompt, tools, and config.

  If `config` contains a `:provider` key (e.g., `:anthropic`), the call is routed
  to that provider via the registry. Otherwise, the default module is used.

  Performance metrics are recorded automatically.

  ## Options

  - `:provider` - Provider name to route to (e.g., `:openai`, `:anthropic`)
  - All other options are passed to the provider's `call/3`
  """
  @spec call(prompt(), tools(), options()) :: {:ok, term()} | {:error, term()}
  def call(prompt, tools, config) when is_list(config) do
    call(prompt, tools, Map.new(config))
  end

  def call(prompt, tools, %{provider: provider_name} = config) when is_atom(provider_name) do
    provider_config = Map.delete(config, :provider)

    case Registry.get(provider_name) do
      {:ok, module} ->
        call_with_tracking(module, provider_name, prompt, tools, provider_config)

      :error ->
        {:error, "Provider #{inspect(provider_name)} not found in registry"}
    end
  end

  def call(prompt, tools, config) do
    call_with_tracking(@default_module, :default, prompt, tools, config)
  end

  @doc """
  Calls an LLM with automatic fallback handling.

  If `config` contains a `:fallback_chain` key with a list of `{provider, config}` tuples,
  those providers are tried in order. Otherwise, auto-fallback uses registry health data.

  Returns `{:ok, response, provider_name}` on success, or `{:error, errors}` if all fail.

  ## Options

  - `:fallback_chain` - List of `{provider_name, config}` tuples
  - `:max_retries` - Retries per provider (default: 1)
  - `:base_backoff_ms` - Base backoff in ms (default: 100)
  - `:circuit_breaker_threshold` - Skip after N consecutive errors (default: 5)
  """
  @spec call_with_fallback(prompt(), tools(), options()) ::
          {:ok, term(), atom()} | {:error, [{atom(), term()}]}
  def call_with_fallback(prompt, tools, config) when is_list(config) do
    call_with_fallback(prompt, tools, Map.new(config))
  end

  def call_with_fallback(prompt, tools, %{fallback_chain: chain_config} = config)
      when is_list(chain_config) do
    base_config =
      Map.drop(config, [
        :fallback_chain,
        :max_retries,
        :base_backoff_ms,
        :circuit_breaker_threshold
      ])

    chain_opts =
      config
      |> Map.take([:max_retries, :base_backoff_ms, :circuit_breaker_threshold])
      |> Map.to_list()

    chain = FallbackChain.new(chain_config, chain_opts)
    FallbackChain.call(chain, prompt, tools, base_config)
  end

  def call_with_fallback(prompt, tools, config) do
    opts =
      config
      |> Map.take([:max_retries, :base_backoff_ms, :circuit_breaker_threshold])
      |> Map.to_list()

    base_config =
      Map.drop(config, [:max_retries, :base_backoff_ms, :circuit_breaker_threshold])

    FallbackChain.auto_call(prompt, tools, base_config, opts)
  end

  @doc """
  Lists all registered LLM providers.

  Returns a list of `{name, module, priority}` tuples.
  """
  @spec list_providers() :: [{atom(), module(), integer()}]
  def list_providers do
    Registry.list()
  end

  @doc """
  Returns a cost summary across all providers.

  See `Lux.LLM.CostTracker.summary/1` for options.
  """
  @spec cost_summary(keyword()) :: map()
  def cost_summary(opts \\ []) do
    CostTracker.summary(opts)
  end

  @doc """
  Returns performance analytics across all providers.

  See `Lux.LLM.PerformanceMonitor.analytics/1` for options.
  """
  @spec performance_analytics(keyword()) :: map()
  def performance_analytics(opts \\ []) do
    PerformanceMonitor.analytics(opts)
  end

  # ── Private ─────────────────────────────────────────────────────────

  defp call_with_tracking(module, provider_name, prompt, tools, config) do
    start_time = System.monotonic_time(:millisecond)

    result = module.call(prompt, tools, config)

    latency_ms = System.monotonic_time(:millisecond) - start_time
    status = if match?({:ok, _}, result), do: :ok, else: :error

    # Record performance metrics (best-effort)
    PerformanceMonitor.record_request(provider_name, %{
      latency_ms: latency_ms,
      status: status,
      model: Map.get(config, :model)
    })

    result
  end
end
