defmodule Lux.LLM.Provider do
  @moduledoc """
  Behaviour and struct defining the universal LLM provider interface.

  Every provider (OpenAI, Anthropic, Google AI, Ollama, etc.) implements
  this behaviour, enabling the Provider Registry to manage, select, and
  fallback across providers at runtime.

  ## Example

      defmodule MyProvider do
        @behaviour Lux.LLM.Provider

        @impl true
        def call(prompt, tools, config), do: ...

        @impl true
        def models, do: ["my-model-v1"]

        @impl true
        def estimate_cost(model, input_tokens, output_tokens), do: ...
      end
  """

  @type provider_id :: atom()
  @type config :: map()
  @type call_result :: {:ok, Lux.LLM.Response.t()} | {:error, String.t()}

  @doc """
  Execute an LLM call with the given prompt, tools, and config.
  """
  @callback call(prompt :: String.t(), tools :: list(), config :: config()) :: call_result()

  @doc """
  Return the list of available models for this provider.
  """
  @callback models() :: [String.t()]

  @doc """
  Estimate the cost in USD for a given model and token counts.
  """
  @callback estimate_cost(model :: String.t(), input_tokens :: pos_integer(), output_tokens :: pos_integer()) :: float()

  @doc """
  Check if the provider is currently available (API key present, endpoint reachable).
  """
  @callback available?() :: boolean()

  @optional_callbacks [available?: 0]

  defstruct [
    :id,
    :module,
    :name,
    :models,
    :priority,
    :enabled,
    :config
  ]

  @type t :: %__MODULE__{
    id: provider_id(),
    module: module(),
    name: String.t(),
    models: [String.t()],
    priority: non_neg_integer(),
    enabled: boolean(),
    config: map()
  }

  @doc """
  Create a new provider entry.
  """
  @spec new(keyword()) :: t()
  def new(attrs) do
    %__MODULE__{
      id: Keyword.get(attrs, :id),
      module: Keyword.get(attrs, :module),
      name: Keyword.get(attrs, :name, ""),
      models: Keyword.get(attrs, :models, []),
      priority: Keyword.get(attrs, :priority, 0),
      enabled: Keyword.get(attrs, :enabled, true),
      config: Keyword.get(attrs, :config, %{})
    }
  end

  @doc """
  Check if a module implements the Provider behaviour.
  """
  @spec implements?(module()) :: boolean()
  def implements?(module) do
    Code.ensure_loaded?(module) and
      function_exported?(module, :call, 3) and
      function_exported?(module, :models, 0) and
      function_exported?(module, :estimate_cost, 3)
  end
end
