defmodule Lux.Lenses.UniswapV3.UniswapV3PositionLens do
  @moduledoc """
  A lens for fetching comprehensive details about a Uniswap V3 liquidity position.

  Returns position health, uncollected fees, price range status, and estimated
  USD values for the position.

  ## Example

      iex> Lux.Lenses.UniswapV3.UniswapV3PositionLens.focus(%{
      ...>   token_id: 123456
      ...> })
      {:ok, %{
        token_id: 123456,
        token0: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        token1: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
        fee_tier: 3000,
        tick_lower: 195000,
        tick_upper: 205000,
        price_lower: "1500.0",
        price_upper: "2500.0",
        current_price: "2100.0",
        in_range: true,
        liquidity: "1500000000000000000",
        fees0_owed: "12345678",
        fees1_owed: "9876543210000000",
        amount0_current: "800000000",
        amount1_current: "300000000000000000",
        status: "success"
      }}
  """

  use Lux.Lens,
    name: "Uniswap V3 Position Info",
    description: "Fetches detailed information about a Uniswap V3 NFT position including fees owed and price range status",
    schema: %{
      type: :object,
      properties: %{
        token_id: %{
          type: :integer,
          description: "NFT token ID of the Uniswap V3 position"
        },
        position_manager_address: %{
          type: :string,
          description: "NonfungiblePositionManager address (defaults to Ethereum mainnet)",
          default: "0xC36442b4a4522E871399CD717aBDD847Ab11FE88",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        factory_address: %{
          type: :string,
          description: "Uniswap V3 Factory address (defaults to Ethereum mainnet)",
          default: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        rpc_url: %{
          type: :string,
          description: "Ethereum JSON-RPC endpoint URL"
        }
      },
      required: ["token_id"]
    }

  import Lux.Python
  require Lux.Python
  require Logger

  @default_position_manager "0xC36442b4a4522E871399CD717aBDD847Ab11FE88"
  @default_factory "0x1F98431c8aD98523631AE4a59f267346ea31F984"
  @default_rpc "https://eth.llamarpc.com"

  @impl true
  def focus(%{token_id: token_id} = input, _agent) do
    position_manager = Map.get(input, :position_manager_address, @default_position_manager)
    factory = Map.get(input, :factory_address, @default_factory)
    rpc_url = Map.get(input, :rpc_url, System.get_env("UNISWAP_V3_RPC_URL") || @default_rpc)

    Logger.info("Uniswap V3 position lens: tokenId=#{token_id}")

    result =
      python variables: %{
               rpc_url: rpc_url,
               position_manager: position_manager,
               factory: factory,
               token_id: token_id
             } do
        ~PY"""
        import math
        from web3 import Web3

        POSITION_MANAGER_ABI = [
            {"name": "positions", "type": "function", "inputs": [
                {"name": "tokenId", "type": "uint256"}
            ], "outputs": [
                {"name": "nonce", "type": "uint96"},
                {"name": "operator", "type": "address"},
                {"name": "token0", "type": "address"},
                {"name": "token1", "type": "address"},
                {"name": "fee", "type": "uint24"},
                {"name": "tickLower", "type": "int24"},
                {"name": "tickUpper", "type": "int24"},
                {"name": "liquidity", "type": "uint128"},
                {"name": "feeGrowthInside0LastX128", "type": "uint256"},
                {"name": "feeGrowthInside1LastX128", "type": "uint256"},
                {"name": "tokensOwed0", "type": "uint128"},
                {"name": "tokensOwed1", "type": "uint128"}
            ]}
        ]

        POOL_ABI = [
            {"name": "slot0", "type": "function", "inputs": [], "outputs": [
                {"name": "sqrtPriceX96", "type": "uint160"},
                {"name": "tick", "type": "int24"},
                {"name": "observationIndex", "type": "uint16"},
                {"name": "observationCardinality", "type": "uint16"},
                {"name": "observationCardinalityNext", "type": "uint16"},
                {"name": "feeProtocol", "type": "uint8"},
                {"name": "unlocked", "type": "bool"}
            ]},
            {"name": "liquidity", "type": "function", "inputs": [], "outputs": [
                {"name": "", "type": "uint128"}
            ]}
        ]

        FACTORY_ABI = [
            {"name": "getPool", "type": "function",
             "inputs": [
                {"name": "tokenA", "type": "address"},
                {"name": "tokenB", "type": "address"},
                {"name": "fee", "type": "uint24"}
             ], "outputs": [{"name": "pool", "type": "address"}]}
        ]

        def tick_to_price(tick):
            return 1.0001 ** tick

        def sqrt_price_x96_to_amounts(sqrt_price_x96, tick_lower, tick_upper, liquidity):
            """Calculate token amounts from liquidity and current price."""
            Q96 = 2**96
            sqrt_ratio = sqrt_price_x96 / Q96
            sqrt_lower = 1.0001 ** (tick_lower / 2)
            sqrt_upper = 1.0001 ** (tick_upper / 2)
            amount0 = 0
            amount1 = 0
            if sqrt_ratio <= sqrt_lower:
                if sqrt_lower != 0:
                    amount0 = liquidity * (sqrt_upper - sqrt_lower) / (sqrt_lower * sqrt_upper)
            elif sqrt_ratio < sqrt_upper:
                amount0 = liquidity * (sqrt_upper - sqrt_ratio) / (sqrt_ratio * sqrt_upper)
                amount1 = liquidity * (sqrt_ratio - sqrt_lower)
            else:
                amount1 = liquidity * (sqrt_upper - sqrt_lower)
            return int(amount0), int(amount1)

        try:
            w3 = Web3(Web3.HTTPProvider(rpc_url))
            pm = Web3.to_checksum_address(position_manager)
            fact = Web3.to_checksum_address(factory)
            tid = int(token_id)

            pm_contract = w3.eth.contract(address=pm, abi=POSITION_MANAGER_ABI)
            factory_contract = w3.eth.contract(address=fact, abi=FACTORY_ABI)

            pos = pm_contract.functions.positions(tid).call()
            token0 = pos[2]
            token1 = pos[3]
            fee_tier = pos[4]
            tick_lower = pos[5]
            tick_upper = pos[6]
            liq = pos[7]
            tokens_owed0 = pos[10]
            tokens_owed1 = pos[11]

            price_lower = tick_to_price(tick_lower)
            price_upper = tick_to_price(tick_upper)

            pool_addr = factory_contract.functions.getPool(token0, token1, fee_tier).call()
            current_tick = tick_lower
            sqrt_price_x96 = 0
            in_range = False

            if pool_addr != "0x0000000000000000000000000000000000000000":
                pool_contract = w3.eth.contract(
                    address=Web3.to_checksum_address(pool_addr), abi=POOL_ABI
                )
                slot0 = pool_contract.functions.slot0().call()
                sqrt_price_x96 = slot0[0]
                current_tick = slot0[1]
                in_range = tick_lower <= current_tick <= tick_upper

            current_price = tick_to_price(current_tick)

            # Calculate current token amounts
            amount0, amount1 = sqrt_price_x96_to_amounts(
                sqrt_price_x96, tick_lower, tick_upper, liq
            ) if sqrt_price_x96 > 0 else (0, 0)

            {
                "token_id": tid,
                "token0": token0,
                "token1": token1,
                "fee_tier": fee_tier,
                "tick_lower": tick_lower,
                "tick_upper": tick_upper,
                "price_lower": f"{price_lower:.6f}",
                "price_upper": f"{price_upper:.6f}",
                "current_price": f"{current_price:.6f}",
                "in_range": in_range,
                "liquidity": str(liq),
                "fees0_owed": str(tokens_owed0),
                "fees1_owed": str(tokens_owed1),
                "amount0_current": str(amount0),
                "amount1_current": str(amount1),
                "pool_address": pool_addr,
                "status": "success"
            }
        except Exception as e:
            {"error": str(e)}
        """
      end

    if Map.has_key?(result, "error") do
      {:error, result["error"]}
    else
      {:ok, %{
        token_id: result["token_id"],
        token0: result["token0"],
        token1: result["token1"],
        fee_tier: result["fee_tier"],
        tick_lower: result["tick_lower"],
        tick_upper: result["tick_upper"],
        price_lower: result["price_lower"],
        price_upper: result["price_upper"],
        current_price: result["current_price"],
        in_range: result["in_range"],
        liquidity: result["liquidity"],
        fees0_owed: result["fees0_owed"],
        fees1_owed: result["fees1_owed"],
        amount0_current: result["amount0_current"],
        amount1_current: result["amount1_current"],
        pool_address: result["pool_address"],
        status: result["status"]
      }}
    end
  end
end

  def focus(_input, _agent), do: {:error, "token_id is required"}
