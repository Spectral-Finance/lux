defmodule Lux.Lenses.PancakeSwap.GetSwapQuote do
  @moduledoc """
  A lens for retrieving PancakeSwap V2 swap quotes.
  """

  use Lux.Lens,
    name: "PancakeSwap Swap Quote",
    description: "Fetches expected output amount for a swap",
    schema: %{
      type: :object,
      properties: %{
        amount_in: %{
          type: :string,
          description: "Amount of input token (in wei)"
        },
        path: %{
          type: :array,
          items: %{type: :string},
          description: "Path of token addresses (e.g. [TokenA, TokenB])"
        }
      },
      required: ["amount_in", "path"]
    }

  alias Lux.Integrations.PancakeSwap.Router

  # PancakeSwap V2 Router on BSC
  @router_address "0x10ED43C718714eb63d5aA57B78B54704E256024E"

  @impl true
  def handler(params, _agent) do
    amount_in = String.to_integer(params.amount_in)
    
    case Router.get_amounts_out(amount_in, params.path, to: @router_address) do
      {:ok, amounts} ->
        amount_out = List.last(amounts)
        {:ok, %{expected_output: to_string(amount_out)}}
        
      {:error, reason} ->
        {:error, "Failed to fetch swap quote: #{inspect(reason)}"}
    end
  end
end
