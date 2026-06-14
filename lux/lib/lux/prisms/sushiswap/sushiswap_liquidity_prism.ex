defmodule Lux.Prisms.Sushiswap.SushiswapLiquidityPrism do
  @moduledoc """
  Tracks SushiSwap LP positions and reward optimization.

  ## Example

      iex> Lux.Prisms.Sushiswap.SushiswapLiquidityPrism.run(%{
      ...>   address: "0xYourAddress",
      ...>   pair_address: "0xPairAddress",
      ...>   chain_id: 56
      ...> })
      {:ok, %{status: "success", lp_balance: "...", share_pct: "..."}}
  """

  use Lux.Prism,
    name: "SushiSwap Liquidity Position Tracker",
    description: "Tracks LP positions, share percentage and reward optimization",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Wallet address to check LP position"
        },
        pair_address: %{
          type: :string,
          description: "SushiSwap pair contract address"
        },
        chain_id: %{
          type: :integer,
          default: 56
        }
      },
      required: ["address", "pair_address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        lp_balance: %{type: :string},
        share_pct: %{type: :string},
        token0_amount: %{type: :string},
        token1_amount: %{type: :string},
        total_supply: %{type: :string}
      },
      required: ["status"]
    }

  import Lux.Python
  require Lux.Python

  @rpcs %{
    1     => "https://eth.llamarpc.com",
    56    => "https://bsc-dataseed.binance.org/",
    137   => "https://polygon-rpc.com",
    42_161 => "https://arb1.arbitrum.io/rpc"
  }

  def handler(input, _ctx) do
    chain_id = input[:chain_id] || input["chain_id"] || 56
    address = input[:address] || input["address"]
    pair_address = input[:pair_address] || input["pair_address"]
    rpc_url = @rpcs[chain_id] || @rpcs[56]

    result =
      python variables: %{
        rpc_url:      rpc_url,
        address:      address,
        pair_address: pair_address
      } do
        ~PY"""
        from web3 import Web3
        from web3.middleware import ExtraDataToPOAMiddleware

        w3 = Web3(Web3.HTTPProvider(rpc_url))
        w3.middleware_onion.inject(ExtraDataToPOAMiddleware, layer=0)

        PAIR_ABI = [
          {"inputs":[{"name":"owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
          {"inputs":[],"name":"totalSupply","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
          {"inputs":[],"name":"getReserves","outputs":[{"name":"_reserve0","type":"uint112"},{"name":"_reserve1","type":"uint112"},{"name":"_blockTimestampLast","type":"uint32"}],"stateMutability":"view","type":"function"},
          {"inputs":[],"name":"token0","outputs":[{"name":"","type":"address"}],"stateMutability":"view","type":"function"},
          {"inputs":[],"name":"token1","outputs":[{"name":"","type":"address"}],"stateMutability":"view","type":"function"}
        ]

        pair     = w3.eth.contract(address=Web3.to_checksum_address(pair_address), abi=PAIR_ABI)
        lp_bal   = pair.functions.balanceOf(Web3.to_checksum_address(address)).call()
        supply   = pair.functions.totalSupply().call()
        reserves = pair.functions.getReserves().call()

        if supply == 0:
          {"error": "Pool has no liquidity"}
        else:
          share      = lp_bal / supply
          token0_amt = int(reserves[0] * share)
          token1_amt = int(reserves[1] * share)
          share_pct  = round(share * 100, 6)
          {
            "status":        "success",
            "lp_balance":    str(lp_bal),
            "total_supply":  str(supply),
            "share_pct":     f"{share_pct}%",
            "token0_amount": str(token0_amt),
            "token1_amount": str(token1_amt),
            "reserve0":      str(reserves[0]),
            "reserve1":      str(reserves[1])
          }
        """
      end

    case result do
      %{"error" => e}          -> {:error, e}
      %{"status" => "success"} = r -> {:ok, r}
      _ -> {:error, "Unexpected response"}
    end
  end
end
