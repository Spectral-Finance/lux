defmodule Lux.Prisms.Uniswap.AddLiquidity do
  @moduledoc """
  Prism for encoding Uniswap V3 mint/add liquidity transactions.
  Encodes NonfungiblePositionManager.mint() parameters.
  """

  use Lux.Prism,
    name: "Uniswap.AddLiquidity",
    description: "Encodes Uniswap V3 mint liquidity transaction calldata",
    input_schema: %{
      type: :object,
      properties: %{
        token0: %{type: :string, description: "Token0 address"},
        token1: %{type: :string, description: "Token1 address"},
        fee: %{type: :integer, description: "Fee tier"},
        tick_lower: %{type: :integer, description: "Lower tick boundary"},
        tick_upper: %{type: :integer, description: "Upper tick boundary"},
        amount0_desired: %{type: :integer, description: "Amount of token0 desired to add"},
        amount1_desired: %{type: :integer, description: "Amount of token1 desired to add"},
        amount0_min: %{type: :integer, description: "Minimum amount of token0 to add"},
        amount1_min: %{type: :integer, description: "Minimum amount of token1 to add"},
        recipient: %{type: :string, description: "Recipient address for the liquidity NFT"},
        deadline: %{type: :integer, description: "Transaction deadline timestamp"},
        network: %{type: :string, description: "Network target", default: "mainnet"}
      },
      required: ["token0", "token1", "fee", "tick_lower", "tick_upper", "amount0_desired", "amount1_desired", "recipient"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        to: %{type: :string, description: "NonfungiblePositionManager address"},
        calldata: %{type: :string, description: "Hex encoded mint calldata"}
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

    with {:ok, _} <- Uniswap.validate_address(input.token0),
         {:ok, _} <- Uniswap.validate_address(input.token1),
         {:ok, _} <- Uniswap.validate_address(input.recipient),
         {:ok, _} <- Uniswap.validate_fee_tier(input.fee) do
      
      params = %{
        token0: input.token0,
        token1: input.token1,
        fee: input.fee,
        tick_lower: input.tick_lower,
        tick_upper: input.tick_upper,
        amount0_desired: input.amount0_desired,
        amount1_desired: input.amount1_desired,
        amount0_min: Map.get(input, :amount0_min, 0),
        amount1_min: Map.get(input, :amount1_min, 0),
        recipient: input.recipient,
        deadline: deadline
      }

      calldata = Uniswap.encode_mint(params)
      {:ok, %{to: pm_address, calldata: calldata}}
    end
  end
end
