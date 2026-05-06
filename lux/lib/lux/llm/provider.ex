defmodule Lux.LLM.Provider do
  @moduledoc """
  Defines the behaviour for LLM providers in the Lux ecosystem.

  All LLM providers (OpenAI, Anthropic, Mira, TogetherAI, etc.) must implement
  this behaviour to be registered in the `Lux.LLM.Registry` and usable through
  the `Lux.LLM.Manager`.

  ## Callbacks

    * `call/3` - Send a prompt with optional tools and config to the provider
    * `models/0` - Return a list of available models for this provider
    * `models/1` - Return filtered/available models given specific criteria
    * `cost/1` - Return cost estimate for a given model
    * `capabilities/0` - Return the capabilities of this provider
    * `default_config/0` - Return the default configuration for this provider

  ## Capabilities

  Providers should declare their capabilities using the `t:Lux.LLM.Provider.capabilities/0` type.
  """

  @typedoc """
  A list of capabilities a provider supports.

    - `:chat` - Standard chat completions
    - `:tools` - Function/tool calling
    - `:streaming` - Streaming responses
    - `:vision` - Image understanding
    - `:json_mode` - Structured JSON output
    - `:embeddings` - Text embeddings
    - `:fine_tuning` - Model fine-tuning
    - `:caching` - Prompt caching
  """
  @type capability ::
          :chat | :tools | :streaming | :vision | :json_mode | :embeddings | :fine_tuning | :caching

  @typedoc """
  Provider metadata used for registration and routing decisions.
  """
  @type provider_metadata :: %{
          required(:name) => String.t(),
          required(:module) => module(),
          optional(:description) => String.t(),
          optional(:models) => [String.t()],
          optional(:capabilities) => [capability()],
          optional(:cost_per_1k_input_tokens) => float(),
          optional(:cost_per_1k_output_tokens) => float(),
          optional(:priority) => non_neg_integer(),
          optional(:enabled) => boolean(),
          optional(:tags) => [String.t()]
        }

  @typedoc """
  Cost information for a given model.
  """
  @type cost_info :: %{
          required(:model) => String.t(),
          required(:input_per_1k_tokens) => float(),
          required(:output_per_1k_tokens) => float(),
          optional(:currency) => String.t()
        }

  @doc """
  Send a prompt to the LLM provider with optional tools and configuration.

  Returns `{:ok, Lux.LLM.Response.t()}` on success or `{:error, term()}` on failure.
  """
  @callback call(prompt :: String.t(), tools :: list(), options :: map()) ::
              {:ok, Lux.LLM.Response.t()} | {:error, term()}

  @doc """
  Return a list of available models for this provider.

  Each model is a string identifier (e.g., `"gpt-4"`, `"claude-3-opus-20240229"`).
  """
  @callback models() :: [String.t()]

  @doc """
  Return the list of models that match the given criteria.

  Criteria can include capability requirements, cost limits, etc.
  """
  @callback models(criteria :: keyword()) :: [String.t()]

  @doc """
  Return cost information for a specific model.

  Returns `{:ok, cost_info()}` if the model is known, `{:error, :unknown_model}` otherwise.
  """
  @callback cost(model :: String.t()) :: {:ok, cost_info()} | {:error, :unknown_model}

  @doc """
  Return the list of capabilities this provider supports.

  See `t:capability/0` for possible values.
  """
  @callback capabilities() :: [capability()]

  @doc """
  Return the default configuration struct for this provider.

  This is used by the Registry to instantiate provider configs.
  """
  @callback default_config() :: struct()

  @doc """
  Return metadata about this provider for registration purposes.
  """
  @callback metadata() :: provider_metadata()

  @optional_callbacks models: 1,
                      cost: 1,
                      capabilities: 0,
                      default_config: 0,
                      metadata: 0

  @doc """
  Checks if a provider module implements the Provider behaviour.
  """
  @spec implements?(module()) :: boolean()
  def implements?(module) when is_atom(module) do
    Code.ensure_loaded?(module) && function_exported?(module, :call, 3)
  end

  @doc """
  Returns a human-readable name for a capability.
  """
  @spec capability_name(capability()) :: String.t()
  def capability_name(:chat), do: "Chat Completions"
  def capability_name(:tools), do: "Function/Tool Calling"
  def capability_name(:streaming), do: "Streaming"
  def capability_name(:vision), do: "Vision/Image Understanding"
  def capability_name(:json_mode), do: "JSON Structured Output"
  def capability_name(:embeddings), do: "Text Embeddings"
  def capability_name(:fine_tuning), do: "Fine-tuning"
  def capability_name(:caching), do: "Prompt Caching"
  def capability_name(other), do: Atom.to_string(other)
end
