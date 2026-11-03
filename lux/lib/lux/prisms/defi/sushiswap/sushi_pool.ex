defmodule Lux.Prisms.Defi.SushiSwap.SushiPoolPrism do
  @moduledoc """
  Builds and queries SushiSwap multi-chain pool state.
  """

  use Lux.Prism,
    name: "SushiSwap Pool Prism",
    description: "Builds and formats SushiSwap pool configuration and mid price across supported chains",
    input_schema: %{
      type: :object,
      properties: %{
        chain_id: %{type: :integer, description: "Chain ID, e.g. 1 for Ethereum, 42161 for Arbitrum"},
        version: %{type: :string, default: "v2"},
        token0: %{type: :string, description: "Token 0 symbol"},
        token1: %{type: :string, description: "Token 1 symbol"},
        reserve0: %{type: :number, default: 1000.0},
        reserve1: %{type: :number, default: 2500000.0}
      },
      required: ["chain_id", "token0", "token1"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string},
        chain_id: %{type: :integer},
        token0: %{type: :string},
        token1: %{type: :string},
        mid_price: %{type: :number}
      },
      required: ["id", "chain_id", "token0", "token1", "mid_price"]
    }

  alias Lux.Defi.SushiSwap.PoolManager

  def handler(input, _ctx) do
    chain_id = Map.get(input, :chain_id) || Map.get(input, "chain_id", 1)
    v_str = Map.get(input, :version) || Map.get(input, "version", "v2")
    version = String.to_atom(v_str)
    token0 = Map.get(input, :token0) || Map.get(input, "token0")
    token1 = Map.get(input, :token1) || Map.get(input, "token1")
    r0 = (Map.get(input, :reserve0) || Map.get(input, "reserve0", 1000.0)) * 1.0
    r1 = (Map.get(input, :reserve1) || Map.get(input, "reserve1", 2_500_000.0)) * 1.0

    pool = PoolManager.build_pool(chain_id, version, token0, token1, r0, r1)
    {:ok, pool}
  end
end
