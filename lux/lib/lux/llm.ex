defmodule Lux.LLM do
  @moduledoc """
  LLM Provider Abstraction for Lux.

  This module defines the core behaviour that all LLM providers must implement,
  along with a centralized response struct and a provider registry for
  runtime provider selection.

  ## Architecture

  The LLM abstraction consists of three layers:

  1. **Behaviour** (`Lux.LLM`) - The callback contract all providers implement
  2. **Response** (`Lux.LLM.Response`) - Unified response struct across providers
  3. **Provider Registry** (`Lux.LLM.Provider`) - Runtime discovery and selection

  ## Adding a New Provider

  To add a new LLM provider:

      defmodule MyProvider do
        @behaviour Lux.LLM

        @impl true
        def call(prompt, tools, config) do
          # Implementation using Req, HTTPoison, etc.
          {:ok, %Lux.LLM.Response{content: "...", ...}}
        end
      end

  Then register it:

      Lux.LLM.Provider.register(:my_provider, MyProvider, %{priority: 1})

  ## Default Provider

  The default provider is configured at compile time via
  `Application.compile_env(:lux, [Lux.LLM, :default_module], Lux.LLM.OpenAI)`.
  At runtime, use `Lux.LLM.Provider.call/3` to select providers dynamically.
  """

  defmodule Response do
    @moduledoc """
    Unified response struct from any LLM provider.

    All providers must return `{:ok, %Response{...}}` or `{:error, reason}`
    to maintain a consistent interface across different LLM backends.

    ## Fields

      * `content` - The text/content response from the model
      * `tool_calls` - List of tool/function calls requested by the model
      * `finish_reason` - Why the model stopped generating (e.g., "stop", "tool_calls")
      * `structured_output` - Parsed structured data if the model returned JSON
      * `model` - The model name that generated this response
      * `usage` - Token usage metadata (input_tokens, output_tokens, etc.)
      * `provider` - The provider module that generated this response

    ## Example

        %{
          content: "{\\"result\\": \\"success\\"}",
          tool_calls: [],
          finish_reason: "stop",
          structured_output: %{"result" => "success"},
          model: "gpt-4",
          usage: %{input_tokens: 100, output_tokens: 50},
          provider: Lux.LLM.OpenAI
        }
    """

    @type tool_call :: %{
            type: String.t(),
            name: String.t(),
            params: map()
          }

    @type usage :: %{
            optional(:input_tokens) => non_neg_integer(),
            optional(:output_tokens) => non_neg_integer(),
            optional(:total_tokens) => non_neg_integer()
          }

    @type t :: %__MODULE__{
            content: String.t() | nil,
            tool_calls: [tool_call()],
            finish_reason: String.t() | nil,
            structured_output: map() | nil,
            model: String.t() | nil,
            usage: usage() | nil,
            provider: module() | nil
          }

    defstruct content: nil,
              tool_calls: [],
              finish_reason: nil,
              structured_output: nil,
              model: nil,
              usage: nil,
              provider: nil
  end

  @type prompt :: String.t()
  @type tools :: [Lux.Prism.t() | Lux.Beam.t() | Lux.Lens.t()]
  @type options :: map() | keyword()

  @callback call(prompt(), tools(), options()) ::
              {:ok, Response.t()} | {:error, String.t()}

  @default_module Application.compile_env(:lux, [Lux.LLM, :default_module], Lux.LLM.OpenAI)

  @doc """
  Calls the default LLM provider with the given prompt, tools, and options.

  This is a convenience wrapper around `Lux.LLM.Provider.call/3` that
  uses the compile-time configured default module.

  ## Examples

      iex> Lux.LLM.call("Hello", [])
      {:ok, %Lux.LLM.Response{...}}
  """
  @spec call(prompt(), tools(), options()) :: {:ok, Response.t()} | {:error, String.t()}
  def call(prompt, tools \\ [], options \\ %{}) do
    @default_module.call(prompt, tools, options)
  end

  @doc """
  Returns the default provider module.
  """
  @spec default_module() :: module()
  def default_module, do: @default_module

  @doc """
  Returns a list of all known provider modules.
  """
  @spec known_providers() :: [module()]
  def known_providers do
    [
      Lux.LLM.OpenAI,
      Lux.LLM.Anthropic,
      Lux.LLM.TogetherAI,
      Lux.LLM.Mira,
      Lux.LLM.OpenRouter
    ]
  end

  @doc """
  Normalizes a response from any provider into a standard Lux.LLM.Response.

  If the input is already a `Lux.LLM.Response`, returns it unchanged.
  If the input is a `Lux.Signal` (from older providers), extracts the
  relevant fields into a `Lux.LLM.Response`.
  """
  @spec normalize_response(any(), module()) :: Response.t()
  def normalize_response(%Response{} = resp, provider \\ nil) do
    case provider do
      nil -> resp
      mod -> Map.put_new(resp, :provider, mod)
    end
  end

  def normalize_response(signal = %Lux.Signal{}, provider) when is_atom(provider) do
    %Response{
      content: signal.payload[:content] || signal.payload["content"],
      tool_calls: signal.payload[:tool_calls] || signal.payload["tool_calls"] || [],
      finish_reason: signal.payload[:finish_reason] || signal.payload["finish_reason"],
      structured_output: signal.payload[:content] || signal.payload["content"],
      model: signal.payload[:model] || signal.payload["model"],
      usage: signal.metadata[:usage] || signal.metadata["usage"],
      provider: provider
    }
  end

  def normalize_response({:ok, response}, provider) when is_map(response) do
    {:ok, normalize_response(response, provider)}
  end

  def normalize_response(other, _provider) do
    other
  end
end
