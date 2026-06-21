defmodule Lux.Prisms.Uniswap.RemoveLiquidity do
  @moduledoc """
  Prism for encoding Uniswap V3 decreaseLiquidity transactions.
  Encodes NonfungiblePositionManager.decreaseLiquidity() parameters.
  """

  use Lux.Prism,
    name: "Uniswap.RemoveLiquidity",
    description: "Encodes Uniswap V3 decreaseLiquidity transaction calldata",
    input_schema: %{
      type: :object,
      properties: %{
        token_id: %{type: :integer, description: "Uniswap V3 Position NFT token ID"},
        liquidity: %{type: :integer, description: "Liquidity amount to decrease"},
        amount0_min: %{type: :integer, description: "Minimum amount of token0 to receive"},
        amount1_min: %{type: :integer, description: "Minimum amount of token1 to receive"},
        deadline: %{type: :integer, description: "Transaction deadline timestamp"},
        network: %{type: :string, description: "Network target", default: "mainnet"}
      },
      required: ["token_id", "liquidity"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        to: %{type: :string, description: "NonfungiblePositionManager address"},
        calldata: %{type: :string, description: "Hex encoded decreaseLiquidity calldata"}
      },
      required: ["to", "calldata"]
    }

  alias Lux.Integrations.Uniswap

  @impl true
  def handler(input, _ctx) do
    network = Map.get(input, :network, "mainnet")
    deadline = Map.get(input, :deadline) || System.system_time(:second) + 600

    Application.put_env(:lux, Uniswap, network: network)

    pm_address = Uniswap.contract_address(:nonfungible_position_manager)

    params = %{
      token_id: input.token_id,
      liquidity: input.liquidity,
      amount0_min: Map.get(input, :amount0_min, 0),
      amount1_min: Map.get(input, :amount1_min, 0),
      deadline: deadline
    }

    calldata = Uniswap.encode_decrease_liquidity(params)
    {:ok, %{to: pm_address, calldata: calldata}}
  end
end
