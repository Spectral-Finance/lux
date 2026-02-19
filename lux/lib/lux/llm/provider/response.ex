defmodule Lux.LLM.Provider.Response do
  @moduledoc """
  Standardized response from any LLM provider.

  This struct provides a unified response format across all providers,
  making it easy to swap providers without changing consuming code.

  ## Fields

  - `:content` - The text content of the response (may be parsed JSON map)
  - `:tool_calls` - List of tool calls requested by the model
  - `:finish_reason` - Why the model stopped generating (e.g., "stop", "tool_calls")
  - `:model` - The model that generated the response
  - `:provider` - The provider module that handled the request
  - `:usage` - Token usage information
  - `:metadata` - Provider-specific metadata
  - `:latency_ms` - Request latency in milliseconds
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
          content: String.t() | map() | nil,
          tool_calls: [tool_call()],
          finish_reason: String.t() | nil,
          model: String.t() | nil,
          provider: module() | nil,
          usage: usage() | nil,
          metadata: map(),
          latency_ms: non_neg_integer() | nil
        }

  defstruct content: nil,
            tool_calls: [],
            finish_reason: nil,
            model: nil,
            provider: nil,
            usage: nil,
            metadata: %{},
            latency_ms: nil

  @doc """
  Returns the estimated cost of this response based on token usage and per-token pricing.

  ## Parameters

  - `response` - The response to calculate cost for
  - `cost_per_input_token` - Cost per input token (default: 0.0)
  - `cost_per_output_token` - Cost per output token (default: 0.0)
  """
  @spec estimated_cost(t(), float(), float()) :: float()
  def estimated_cost(%__MODULE__{usage: nil}, _input_cost, _output_cost), do: 0.0

  def estimated_cost(%__MODULE__{usage: usage}, cost_per_input_token, cost_per_output_token) do
    input_tokens = Map.get(usage, :input_tokens, 0)
    output_tokens = Map.get(usage, :output_tokens, 0)
    input_tokens * cost_per_input_token + output_tokens * cost_per_output_token
  end
end
