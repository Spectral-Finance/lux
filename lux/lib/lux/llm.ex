defmodule Lux.LLM do
  @moduledoc """
  A module for interacting with LLMs. Defines the behaviours for LLMs and provides a default implementation.

  The LLM module now supports a full provider abstraction layer:

  - **Lux.LLM.Provider** — Behaviour and struct defining the universal provider interface
  - **Lux.LLM.ProviderRegistry** — GenServer registry for dynamic provider management
  - **Lux.LLM.ModelSelector** — Intelligent model selection by cost, speed, or capability
  - **Lux.LLM.FallbackHandler** — Automatic fallback with exponential backoff
  - **Lux.LLM.CostTracker** — Token usage and cost tracking across providers
  - **Lux.LLM.PerformanceMonitor** — Latency and success rate monitoring

  ## Quick Start

      # Standard call (delegates to default provider)
      Lux.LLM.call("Explain quantum computing", [], %{})

      # Call with automatic provider selection and fallback
      Lux.LLM.call_with_fallback("Explain AI", [], model: "gpt-4")

      # Register a new provider at runtime
      Lux.LLM.ProviderRegistry.register(:google, Lux.LLM.GoogleAI,
        name: "Google AI", priority: 8, models: ["gemini-pro", "gemini-ultra"])

      # Select the cheapest provider for a model
      Lux.LLM.ModelSelector.select("Translate this", strategy: :cheapest)

      # Track costs
      Lux.LLM.CostTracker.track(:openai, "gpt-4", 1500, 500, 0.045)
      Lux.LLM.CostTracker.total_spend()
  """

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

  defdelegate call(prompt, tools, options), to: @default_module

  @doc """
  Call an LLM with automatic provider selection and fallback.

  Uses the ProviderRegistry to find available providers for the requested
  model, then delegates to the FallbackHandler for resilient execution.

  ## Options

    * `:model` — Target model (e.g., "gpt-4", "claude-3-sonnet")
    * `:strategy` — Fallback strategy (`:priority`, `:cost`, `:random`, `:round_robin`)
    * `:max_retries` — Maximum fallback attempts (default: 3)
    * `:cost_limit_usd` — Maximum cost per request
    * `:temperature` — Sampling temperature
    * `:max_tokens` — Maximum response tokens
    * `:backoff_ms` — Initial backoff in ms (doubles each retry)

  ## Returns

    * `{:ok, response, metadata}` — Successful call with provider metadata
    * `{:error, reason, metadata}` — All providers exhausted
  """
  @spec call_with_fallback(prompt(), tools(), keyword()) ::
    {:ok, Response.t(), map()} | {:error, String.t(), map()}
  def call_with_fallback(prompt, tools, opts \\ []) do
    Lux.LLM.FallbackHandler.call(prompt, tools, opts)
  end

  @doc """
  Auto-select the best model and provider for a given prompt.

  Uses the ModelSelector to pick the optimal model based on the
  configured strategy (default: :balanced).

  ## Options

    * `:strategy` — `:cheapest`, `:fastest`, `:smartest`, or `:balanced` (default)
    * `:cost_limit` — Maximum cost in USD
    * `:preference` — Ordered list of preferred models
    * `:max_tokens` — Maximum response tokens (default: 1000)
  """
  @spec auto_select(prompt(), keyword()) :: {:ok, Response.t(), map()} | {:error, String.t()}
  def auto_select(prompt, opts \\ []) do
    strategy = Keyword.get(opts, :strategy, :balanced)
    cost_limit = Keyword.get(opts, :cost_limit)

    case Lux.LLM.ModelSelector.select(prompt, strategy: strategy, cost_limit: cost_limit) do
      %{model: model, provider: _provider} = selection ->
        call_opts = [
          model: model,
          cost_limit_usd: cost_limit,
          max_retries: 3
        ] ++ opts

        case call_with_fallback(prompt, [], call_opts) do
          {:ok, response, metadata} ->
            {:ok, response, Map.merge(metadata, %{selection: selection})}

          {:error, reason, metadata} ->
            {:error, reason, metadata}
        end

      nil ->
        {:error, "no_provider_available"}
    end
  end
end
