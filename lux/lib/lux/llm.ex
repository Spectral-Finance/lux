defmodule Lux.LLM do
  @moduledoc """
  Universal LLM interface for Lux.
  Defines the behaviour for LLM adapters and delegates provider registry,
  automatic model selection, intelligent fallback, caching, and cost/performance
  telemetry to `Lux.LLM.Provider`.
  """

  alias Lux.LLM.Provider

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

  @callback call(prompt(), tools(), options()) :: {:ok, term()} | {:error, term()}

  @default_module Application.compile_env(:lux, [Lux.LLM, :default_module], Lux.LLM.OpenAI)

  defdelegate call(prompt, tools, options), to: @default_module
  defdelegate call_with_fallback(prompt, tools \\ [], options \\ %{}), to: Provider
  defdelegate select_provider(criteria \\ %{}), to: Provider
  defdelegate register_provider(id, spec), to: Provider
  defdelegate get_provider(id), to: Provider
  defdelegate list_providers(), to: Provider
  defdelegate get_metrics(), to: Provider
  defdelegate reset_metrics(), to: Provider
  defdelegate clear_cache(), to: Provider
end
