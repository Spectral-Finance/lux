defmodule Lux.LLM do
  @moduledoc """
  Universal LLM Provider Abstraction Layer for Lux.

  Defines the behaviour for LLM providers and exposes unified entry points for:
  - Direct provider invocation (`call/3`)
  - Automatic model selection (`call_smart/3`, `Lux.LLM.ModelSelector`)
  - Intelligent multi-provider fallback (`call_with_fallback/3`, `Lux.LLM.FallbackHandler`)
  - Deterministic response caching & cost/latency monitoring (`Lux.LLM.TelemetryAndCache`)
  """

  alias Lux.LLM.FallbackHandler
  alias Lux.LLM.ModelSelector
  alias Lux.LLM.ProviderRegistry
  alias Lux.LLM.TelemetryAndCache

  defmodule Response do
    @moduledoc """
    A standardized response returned by any Lux LLM provider.
    """

    @type t :: %__MODULE__{
            content: String.t() | nil,
            tool_calls: [%{type: String.t(), name: String.t(), params: map()}],
            finish_reason: String.t() | nil,
            structured_output: map() | nil,
            provider: atom() | nil,
            model: String.t() | nil,
            usage: map() | nil,
            cached: boolean()
          }

    defstruct content: nil,
              tool_calls: [],
              finish_reason: nil,
              structured_output: nil,
              provider: nil,
              model: nil,
              usage: nil,
              cached: false
  end

  @type prompt :: String.t()
  @type tools :: [Lux.Prism.t() | Lux.Beam.t() | Lux.Lens.t()]
  @type options :: map() | keyword()

  @callback call(prompt(), tools(), options()) :: {:ok, Response.t() | any()} | {:error, any()}

  @default_module Application.compile_env(:lux, [Lux.LLM, :default_module], Lux.LLM.OpenAI)

  defdelegate call(prompt, tools, options), to: @default_module

  @doc """
  Executes a prompt using automatic model selection, response caching, cost/latency monitoring,
  and intelligent fallback across healthy providers.
  """
  @spec call_smart(prompt(), tools(), options()) :: {:ok, Response.t() | any()} | {:error, any()}
  def call_smart(prompt, tools \\ [], options \\ %{}) do
    opts_map = normalize_options(options)
    use_cache = Map.get(opts_map, :cache, true)

    with {:ok, selection} <- ModelSelector.select(opts_map) do
      cache_key = TelemetryAndCache.cache_key(prompt, tools, selection.model, opts_map)

      case maybe_fetch_cache(use_cache, cache_key) do
        {:hit, cached_response} ->
          TelemetryAndCache.record_cache_hit(selection.provider_id, selection.model)
          {:ok, cached_response}

        :miss ->
          FallbackHandler.execute_with_fallback(prompt, tools, opts_map, selection)
          |> tap_cache_and_metrics(use_cache, cache_key)
      end
    end
  end

  @doc """
  Returns the registered providers and their current status from `Lux.LLM.ProviderRegistry`.
  """
  def list_providers, do: ProviderRegistry.list_providers()

  defp maybe_fetch_cache(false, _key), do: :miss
  defp maybe_fetch_cache(true, key), do: TelemetryAndCache.get_cached(key)

  defp tap_cache_and_metrics({:ok, response} = ok, true, key) do
    TelemetryAndCache.put_cached(key, response)
    ok
  end

  defp tap_cache_and_metrics(other, _use_cache, _key), do: other

  defp normalize_options(opts) when is_list(opts), do: Enum.into(opts, %{})
  defp normalize_options(opts) when is_map(opts), do: opts
  defp normalize_options(_), do: %{}
end
