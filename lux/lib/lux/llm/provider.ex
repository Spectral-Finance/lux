# Fix for Issue #99: LLM Provider Abstraction Layer $600

defmodule Lux.LLM.Provider.Behaviour do
  @moduledoc """
  Defines the behaviour that all LLM providers must implement.
  
  This behaviour establishes a universal interface for interacting with
  different LLM providers, ensuring consistent API across OpenAI, Anthropic,
  Google, and other providers.
  """

  @type message :: %{
    role: String.t(),
    content: String.t()
  }

  @type tool :: %{
    name: String.t(),
    description: String.t(),
    parameters: map()
  }

  @type completion_request :: %{
    model: String.t(),
    messages: [message()],
    temperature: float() | nil,
    max_tokens: integer() | nil,
    tools: [tool()] | nil,
    stream: boolean() | nil,
    metadata: map() | nil
  }

  @type completion_response :: %{
    id: String.t(),
    model: String.t(),
    content: String.t(),
    finish_reason: String.t(),
    usage: %{
      prompt_tokens: integer(),
      completion_tokens: integer(),
      total_tokens: integer()
    },
    tool_calls: [map()] | nil,
    latency_ms: integer(),
    provider: atom()
  }

  @type embedding_request :: %{
    model: String.t(),
    input: String.t() | [String.t()]
  }

  @type embedding_response :: %{
    embeddings: [[float()]],
    model: String.t(),
    usage: %{
      prompt_tokens: integer(),
      total_tokens: integer()
    }
  }

  @type model_info :: %{
    id: String.t(),
    name: String.t(),
    provider: atom(),
    context_window: integer(),
    max_output_tokens: integer(),
    input_cost_per_1k: float(),
    output_cost_per_1k: float(),
    capabilities: [atom()],
    supports_tools: boolean(),
    supports_vision: boolean(),
    supports_streaming: boolean()
  }

  @type error :: {:error, %{
    code: atom(),
    message: String.t(),
    retryable: boolean(),
    details: map() | nil
  }}

  @doc """
  Returns the provider name as an atom.
  """
  @callback name() :: atom()

  @doc """
  Completes a chat conversation with the LLM.
  """
  @callback complete(completion_request(), keyword()) :: 
    {:ok, completion_response()} | error()

  @doc """
  Streams a chat completion response.
  """
  @callback stream(completion_request(), keyword()) ::
    {:ok, Enumerable.t()} | error()

  @doc """
  Generates embeddings for the given input.
  """
  @callback embed(embedding_request(), keyword()) ::
    {:ok, embedding_response()} | error()

  @doc """
  Lists available models for this provider.
  """
  @callback list_models(keyword()) :: {:ok, [model_info()]} | error()

  @doc """
  Returns information about a specific model.
  """
  @callback get_model(String.t()) :: {:ok, model_info()} | {:error, :not_found}

  @doc """
  Validates the provider configuration and credentials.
  """
  @callback validate_config(keyword()) :: :ok | {:error, String.t()}

  @doc """
  Checks if the provider is currently available/healthy.
  """
  @callback health_check(keyword()) :: :ok | {:error, String.t()}

  @optional_callbacks [stream: 2, embed: 2, health_check: 1]
end