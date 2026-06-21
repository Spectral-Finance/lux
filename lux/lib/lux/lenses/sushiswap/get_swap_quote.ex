defmodule Lux.Lenses.SushiSwap.GetSwapQuote do
  @moduledoc """
  A lens for retrieving SushiSwap V2 swap quotes.
  """

  use Lux.Lens,
    name: "SushiSwap Swap Quote",
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

  alias Lux.Integrations.SushiSwap.Router

  # SushiSwap V2 Router on Ethereum
  @router_address "0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F"

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
