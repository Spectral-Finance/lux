defmodule Lux.Lenses.UniswapV3.PoolMonitorLens do
  @moduledoc """
  A lens for inspecting Uniswap V3 pool state, TWAP oracle observations,
  and concentrated tick-range depth.
  """

  use Lux.Lens,
    name: "Uniswap V3 Pool Monitor",
    description: "Reads Uniswap V3 pool slot0, TWAP, volume, and active liquidity metrics",
    url: "https://api.thegraph.com/subgraphs/name/uniswap/uniswap-v3",
    method: :post,
    headers: [{"content-type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        pool_address: %{type: :string},
        token0_symbol: %{type: :string},
        token1_symbol: %{type: :string},
        fee_tier: %{type: :integer},
        current_price: %{type: :number},
        twap_price: %{type: :number},
        daily_volatility: %{type: :number}
      },
      required: ["pool_address"]
    }

  @doc """
  Normalizes raw pool telemetry or subgraph data into a structured snapshot for downstream Prisms.
  """
  def snapshot(params) when is_map(params) do
    price = Map.get(params, :current_price, 2500.0)
    twap = Map.get(params, :twap_price, price)
    vol = Map.get(params, :daily_volatility, 0.028)
    fee_tier = Map.get(params, :fee_tier, 3000)

    {:ok,
     %{
       pool_address: Map.get(params, :pool_address, "0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8"),
       token0_symbol: Map.get(params, :token0_symbol, "WETH"),
       token1_symbol: Map.get(params, :token1_symbol, "USDC"),
       fee_tier: fee_tier,
       current_price: price,
       twap_price: twap,
       daily_volatility: vol
     }}
  end

  def after_focus(response) when is_map(response) do
    {:ok, response}
  end
end
