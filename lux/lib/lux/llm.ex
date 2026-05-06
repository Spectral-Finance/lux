defmodule Lux.LLM do
  @moduledoc """
  A module for interacting with LLMs. Defines the behaviours for LLMs and provides a default implementation.

  ## Entry Points

  For most use cases, use `Lux.LLM.Manager` which provides automatic provider
  selection, fallback, and routing. The functions here delegate to the Manager.

  ## Behaviour

  All LLM providers must implement the `Lux.LLM.Provider` behaviour and be
  registered in `Lux.LLM.Registry`.

  ## Quick Start

      # Auto-select best provider
      Lux.LLM.chat("Hello!")

      # Specify a provider
      Lux.LLM.chat("Hello!", [], provider: Lux.LLM.Anthropic)

      # With tools
      Lux.LLM.chat("What's the weather?", [my_weather_tool])
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
  Send a chat prompt to the LLM.

  Delegates to `Lux.LLM.Manager.chat/3` for automatic provider selection.
  Falls back to the default module (`Lux.LLM.OpenAI`) for backward compatibility.

  ## Examples

      Lux.LLM.chat("Hello")
      Lux.LLM.chat("Hello", [], provider: Lux.LLM.Anthropic)
  """
  def chat(prompt, tools \\ [], options \\ []) do
    Lux.LLM.Manager.chat(prompt, tools, options)
  end

  @doc """
  Send a chat with automatic fallback across providers.

  See `Lux.LLM.Manager.chat_with_fallback/3` for details.
  """
  def chat_with_fallback(prompt, tools \\ [], options \\ []) do
    Lux.LLM.Manager.chat_with_fallback(prompt, tools, options)
  end

  @doc """
  Call an LLM with the default provider (backward compatibility).

  This is kept for backward compatibility with existing code that uses
  `Lux.LLM.call/3` directly.
  """
  def call(prompt, tools, options) do
    @default_module.call(prompt, tools, options)
  end

  @doc """
  List all registered providers.
  """
  def list_providers do
    Lux.LLM.Manager.list_providers()
  end

  @doc """
  List available models.
  """
  def list_models(provider \\ nil) do
    Lux.LLM.Manager.list_models(provider)
  end

  @doc """
  Find providers that support a specific capability.
  """
  def find_by_capability(capability) do
    Lux.LLM.Manager.find_by_capability(capability)
  end
end
