defmodule Lux.LLM do
  @moduledoc """
  A module for interacting with LLMs. Defines the behaviours for LLMs and provides a default implementation.

  ## Provider Registry

  When the `Lux.LLM.ProviderRegistry` is running, calls can be routed through
  it for automatic provider selection, fallback handling, and metrics tracking.

  Use `Lux.LLM.call_with_registry/3` to route through the registry, or
  `Lux.LLM.call/3` for direct provider calls (default behavior, backwards compatible).

  ## Available Providers

  - `Lux.LLM.OpenAI` - OpenAI (GPT-4, GPT-3.5, etc.)
  - `Lux.LLM.Anthropic` - Anthropic (Claude models)
  - `Lux.LLM.TogetherAI` - Together AI (open-source models)
  - `Lux.LLM.Ollama` - Ollama (local models)
  - `Lux.LLM.Mira` - Mira Network

  ## Shared Utilities

  Common provider functionality is available in `Lux.LLM.ProviderUtils`:
  - Tool conversion (Beams/Prisms/Lenses → function definitions)
  - Tool execution
  - Content parsing
  - Response building
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

  @doc """
  Makes an LLM call using the default provider module.

  This is the backwards-compatible entry point that delegates directly
  to the configured default module (defaults to `Lux.LLM.OpenAI`).
  """
  defdelegate call(prompt, tools, options), to: @default_module

  @doc """
  Makes an LLM call through the Provider Registry.

  Routes the call through `Lux.LLM.ProviderRegistry` for automatic
  provider selection, fallback handling, and metrics tracking.

  Requires the ProviderRegistry to be running (add to your supervision tree
  or call `Lux.LLM.ProviderRegistry.start_link/1`).

  ## Options

  All standard provider options plus:
  - `:provider` - Force a specific provider
  - `:fallback` - Enable fallback (default: true)
  - `:max_retries` - Max fallback attempts (default: 3)
  - `:tags` - Select provider by tags

  ## Examples

      Lux.LLM.call_with_registry("Hello!", [], %{model: "gpt-4"})
      Lux.LLM.call_with_registry("Hello!", [], %{provider: :anthropic})
  """
  @spec call_with_registry(prompt(), tools(), map()) :: {:ok, term()} | {:error, term()}
  def call_with_registry(prompt, tools, options) do
    Lux.LLM.ProviderRegistry.call(prompt, tools, options)
  end
end
