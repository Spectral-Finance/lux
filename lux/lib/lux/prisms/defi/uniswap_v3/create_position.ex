defmodule Lux.Prisms.Defi.UniswapV3.CreatePositionPrism do
  @moduledoc """
  Validates and creates a new Uniswap V3 concentrated liquidity position with tick-spacing alignment.
  """

  use Lux.Prism,
    name: "Create Uniswap V3 Position",
    description: "Mints a new concentrated liquidity position on Uniswap V3",
    input_schema: %{
      type: :object,
      properties: %{
        token0: %{type: :string, description: "Address of token0 (0x...)"},
        token1: %{type: :string, description: "Address of token1 (0x...)"},
        fee: %{type: :integer, enum: [100, 500, 3000, 10000], default: 3000},
        tick_lower: %{type: :integer, description: "Lower tick boundary"},
        tick_upper: %{type: :integer, description: "Upper tick boundary"},
        liquidity: %{type: :integer, description: "Liquidity amount to deposit", default: 1000000},
        owner: %{type: :string, description: "Owner wallet address"}
      },
      required: ["token0", "token1", "tick_lower", "tick_upper"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        token_id: %{type: :string},
        pool_address: %{type: :string},
        tick_lower: %{type: :integer},
        tick_upper: %{type: :integer},
        liquidity: %{type: :integer}
      },
      required: ["token_id", "pool_address", "tick_lower", "tick_upper"]
    }

  alias Lux.Defi.UniswapV3.PositionManager

  def handler(input, _ctx) do
    case PositionManager.create_position(input) do
      {:ok, pos} ->
        {:ok,
         %{
           token_id: pos.token_id,
           pool_address: pos.pool_address,
           tick_lower: pos.tick_lower,
           tick_upper: pos.tick_upper,
           liquidity: pos.liquidity
         }}

      {:error, reason} ->
        {:error, "Position creation failed: #{inspect(reason)}"}
    end
  end
end
