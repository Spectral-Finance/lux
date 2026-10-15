defmodule Lux.LLM do
  @moduledoc """
  Universal interface for interacting with Large Language Models (LLMs).

  Defines the `Lux.LLM` behaviour and provides access to the universal provider
  abstraction layer (`Lux.LLM.Router`, `Lux.LLM.ProviderRegistry`,
  `Lux.LLM.ModelSelector`, `Lux.LLM.Telemetry`, and `Lux.LLM.Cache`).
  """

  alias Lux.LLM.Cache
  alias Lux.LLM.ModelSelector
  alias Lux.LLM.ProviderRegistry
  alias Lux.LLM.Router
  alias Lux.LLM.Telemetry

  defmodule Response do
    @moduledoc """
    A normalized response from an LLM.
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

  @callback call(prompt(), tools(), options()) :: {:ok, term()} | {:error, term()}

  @default_module Application.compile_env(:lux, [Lux.LLM, :default_module], Lux.LLM.OpenAI)

  @router_keys [
    :provider,
    :providers,
    :fallback_providers,
    :strategy,
    :auto_select,
    :cache,
    :normalize_response
  ]

  @doc """
  Executes an LLM request.

  When universal routing options (`:provider`, `:providers`, `:fallback_providers`,
  `:strategy`, `:auto_select`, `:cache`, or `:normalize_response`) are supplied,
  routes the request through `Lux.LLM.Router`. Otherwise delegates to the configured
  default LLM module (`Lux.LLM.OpenAI` by default).
  """
  @spec call(prompt(), tools(), options()) :: {:ok, term()} | {:error, term()}
  def call(prompt, tools, options) do
    opts_map = if is_list(options), do: Map.new(options), else: options

    if Enum.any?(@router_keys, &Map.has_key?(opts_map, &1)) do
      Router.call(prompt, tools, opts_map)
    else
      @default_module.call(prompt, tools, options)
    end
  end

  @doc """
  Routes an LLM request through `Lux.LLM.Router` with automatic model selection,
  fallback handling, caching, and telemetry.
  """
  @spec route(prompt(), tools(), options()) :: {:ok, term()} | {:error, term()}
  def route(prompt, tools \\ [], options \\ %{}) do
    Router.call(prompt, tools, options)
  end

  @doc """
  Selects the optimal provider and model for a given prompt, tools list, and options.
  """
  @spec select_model(prompt(), tools(), options()) ::
          {:ok, ModelSelector.selection()} | {:error, :no_matching_model}
  def select_model(prompt, tools \\ [], options \\ %{}) do
    opts_map = if is_list(options), do: Map.new(options), else: options
    ModelSelector.select(prompt, tools, opts_map)
  end

  @doc """
  Registers a provider in `Lux.LLM.ProviderRegistry`.
  """
  defdelegate register_provider(id, spec), to: ProviderRegistry

  @doc """
  Lists registered providers from `Lux.LLM.ProviderRegistry`.
  """
  defdelegate list_providers(opts \\ []), to: ProviderRegistry

  @doc """
  Returns aggregated cost, token, and latency metrics from `Lux.LLM.Telemetry`.
  """
  defdelegate metrics(), to: Telemetry, as: :get_metrics

  @doc """
  Clears the LLM response cache.
  """
  defdelegate clear_cache(), to: Cache, as: :clear!
end
