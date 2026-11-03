defmodule Lux.LLM.Provider do
  @moduledoc """
  Defines the universal behaviour and contract for LLM providers in Lux.

  Any LLM provider (OpenAI, Anthropic, TogetherAI, OpenRouter, Ollama, Perplexity, etc.)
  implements this behaviour to provide uniform access, cost estimation, model discovery,
  and health status checks.
  """

  alias Lux.LLM.Response

  @type prompt :: String.t()
  @type tools :: [Lux.Prism.t() | Lux.Beam.t() | Lux.Lens.t()]
  @type options :: map() | keyword()
  @type model_info :: %{
          id: String.t(),
          name: String.t(),
          context_window: integer(),
          supports_tools: boolean(),
          supports_vision: boolean(),
          cost_per_million_input: float(),
          cost_per_million_output: float()
        }

  @callback call(prompt(), tools(), options()) :: {:ok, Response.t()} | {:error, term()}
  @callback list_models() :: [model_info()]
  @callback calculate_cost(prompt_tokens :: integer(), completion_tokens :: integer(), model :: String.t()) :: float()
  @callback health_check() :: :ok | {:error, term()}

  @optional_callbacks [health_check: 0]
end
