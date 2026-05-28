defmodule Lux.LLM do
  @moduledoc """
  A module for interacting with LLMs. Defines the behaviours for LLMs and provides a default implementation.
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
  Returns the built-in stateless provider registry.
  """
  def providers, do: Lux.LLM.ProviderRegistry.default_registry()

  @doc """
  Selects a provider/model for a request using the built-in registry.
  """
  def select_provider(request \\ %{}) do
    Lux.LLM.ProviderRegistry.select(providers(), request)
  end

  @doc """
  Calls the selected provider directly.

  This keeps routing opt-in and preserves `call/3` as the configured default
  provider path.
  """
  def call_provider(prompt, tools, request, options \\ %{}) do
    with {:ok, %{provider: provider, model: model}} <- select_provider(request) do
      options =
        options
        |> Map.new()
        |> Map.merge(provider.config)
        |> Map.put(:model, model)

      provider.module.call(prompt, tools, options)
    end
  end
end
