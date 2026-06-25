defmodule Lux.LLM.Provider.Model do
  @moduledoc """
  Represents an LLM model with its capabilities and metadata.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          provider: module(),
          name: String.t(),
          capabilities: [atom()],
          max_tokens: integer(),
          context_window: integer(),
          cost_per_input_token: Decimal.t(),
          cost_per_output_token: Decimal.t(),
          metadata: map()
        }

  defstruct [
    :id,
    :provider,
    :name,
    :capabilities,
    :max_tokens,
    :context_window,
    :cost_per_input_token,
    :cost_per_output_token,
    :metadata
  ]

  @doc """
  Creates a new Model struct with the given attributes.
  """
  def new(attrs) do
    struct!(__MODULE__, attrs)
  end

  @doc """
  Checks if the model supports a given capability.
  """
  def supports?(%__MODULE__{capabilities: capabilities}, capability) when is_atom(capability) do
    capability in capabilities
  end

  @doc """
  Calculates the estimated cost for given input and output tokens.
  """
  def estimate_cost(%__MODULE__{} = model, input_tokens, output_tokens) do
    input_cost = Decimal.mult(model.cost_per_input_token, Decimal.new(input_tokens))
    output_cost = Decimal.mult(model.cost_per_output_token, Decimal.new(output_tokens))
    Decimal.add(input_cost, output_cost)
  end

  def estimate_cost(_, _, _) do
    nil
  end
end