defmodule Lux.Lenses.UniswapV3.UniswapV3OptimalRangeLens do
  @moduledoc """
  A lens for calculating optimal price ranges for Uniswap V3 positions.

  Analyzes recent price history and volatility to suggest the optimal tick range
  for a new position, balancing fee capture against impermanent loss risk.

  Returns suggested price bounds and estimated fee APY based on pool activity.

  ## Example

      iex> Lux.Lenses.UniswapV3.UniswapV3OptimalRangeLens.focus(%{
      ...>   token0: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      ...>   token1: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
      ...>   fee: 3000,
      ...>   range_multiplier: 2.0
      ...> })
      {:ok, %{
        current_price: "2150.456789",
        suggested_price_lower: "1950.0",
        suggested_price_upper: "2370.0",
        suggested_tick_lower: 197500,
        suggested_tick_upper: 202500,
        volatility_1d: "0.045",
        estimated_fee_apy: "12.5",
        pool_address: "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
        status: "success"
      }}
  """

  use Lux.Lens,
    name: "Uniswap V3 Optimal Range",
    description: "Calculates optimal price range for Uniswap V3 liquidity based on volatility and fee data",
    schema: %{
      type: :object,
      properties: %{
        token0: %{
          type: :string,
          description: "Address of token0",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        token1: %{
          type: :string,
          description: "Address of token1",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        fee: %{
          type: :integer,
          description: "Pool fee tier: 100, 500, 3000, or 10000",
          enum: [100, 500, 3000, 10000],
          default: 3000
        },
        range_multiplier: %{
          type: :number,
          description: "Range multiplier applied to 1-day volatility (default 2.0 = 2 standard deviations)",
          default: 2.0,
          minimum: 0.5,
          maximum: 10.0
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
      required: ["token0", "token1"]
    }

  import Lux.Python
  require Lux.Python
  require Logger

  @default_factory "0x1F98431c8aD98523631AE4a59f267346ea31F984"
  @default_rpc "https://eth.llamarpc.com"

  @impl true
  def focus(%{token0: token0, token1: token1} = input, _agent) do
    factory = Map.get(input, :factory_address, @default_factory)
    rpc_url = Map.get(input, :rpc_url, System.get_env("UNISWAP_V3_RPC_URL") || @default_rpc)
    fee = Map.get(input, :fee, 3000)
    range_multiplier = Map.get(input, :range_multiplier, 2.0)

    Logger.info("Uniswap V3 optimal range: #{token0}/#{token1} fee=#{fee}")

    result =
      python variables: %{
               rpc_url: rpc_url,
               factory: factory,
               token0: token0,
               token1: token1,
               fee: fee,
               range_multiplier: range_multiplier
             } do
        ~PY"""
        import math
        from web3 import Web3

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
            ]},
            {"name": "observe", "type": "function",
             "inputs": [{"name": "secondsAgos", "type": "uint32[]"}],
             "outputs": [
                {"name": "tickCumulatives", "type": "int56[]"},
                {"name": "secondsPerLiquidityCumulativeX128s", "type": "uint160[]"}
             ]},
            {"name": "feeGrowthGlobal0X128", "type": "function", "inputs": [], "outputs": [
                {"name": "", "type": "uint256"}
            ]},
            {"name": "feeGrowthGlobal1X128", "type": "function", "inputs": [], "outputs": [
                {"name": "", "type": "uint256"}
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

        ERC20_ABI = [
            {"name": "balanceOf", "type": "function",
             "inputs": [{"name": "account", "type": "address"}],
             "outputs": [{"name": "", "type": "uint256"}]},
            {"name": "decimals", "type": "function", "inputs": [], "outputs": [{"name": "", "type": "uint8"}]}
        ]

        FEE_TO_TICK_SPACING = {100: 1, 500: 10, 3000: 60, 10000: 200}

        def tick_to_price(tick):
            return 1.0001 ** tick

        def price_to_tick(price):
            return math.floor(math.log(float(price)) / math.log(1.0001))

        def nearest_usable_tick(tick, tick_spacing):
            return round(tick / tick_spacing) * tick_spacing

        try:
            w3 = Web3(Web3.HTTPProvider(rpc_url))
            fact = Web3.to_checksum_address(factory)
            factory_contract = w3.eth.contract(address=fact, abi=FACTORY_ABI)

            pool_addr = factory_contract.functions.getPool(
                Web3.to_checksum_address(token0),
                Web3.to_checksum_address(token1),
                int(fee)
            ).call()

            if pool_addr == "0x0000000000000000000000000000000000000000":
                raise ValueError(f"Pool not found for {token0}/{token1} fee={fee}")

            pool_contract = w3.eth.contract(address=pool_addr, abi=POOL_ABI)

            slot0 = pool_contract.functions.slot0().call()
            current_tick = slot0[1]
            current_price = tick_to_price(current_tick)
            pool_liq = pool_contract.functions.liquidity().call()

            tick_spacing = FEE_TO_TICK_SPACING.get(int(fee), 60)

            # Estimate volatility using TWAP observations (1h and 24h)
            try:
                obs = pool_contract.functions.observe([0, 3600, 86400]).call()
                tick_cumulative_now = obs[0][0]
                tick_cumulative_1h_ago = obs[0][1]
                tick_cumulative_24h_ago = obs[0][2]

                twap_1h = (tick_cumulative_now - tick_cumulative_1h_ago) / 3600
                twap_24h = (tick_cumulative_now - tick_cumulative_24h_ago) / 86400

                price_1h = tick_to_price(twap_1h)
                price_24h = tick_to_price(twap_24h)

                # Estimated 1-day volatility
                if price_24h > 0:
                    vol_1d = abs(math.log(current_price / price_24h))
                else:
                    vol_1d = 0.05
            except:
                vol_1d = 0.05  # Default 5% if TWAP unavailable

            # Calculate range based on volatility and multiplier
            half_range = vol_1d * float(range_multiplier)
            price_lower = current_price * math.exp(-half_range)
            price_upper = current_price * math.exp(half_range)

            tick_lower = nearest_usable_tick(price_to_tick(price_lower), tick_spacing)
            tick_upper = nearest_usable_tick(price_to_tick(price_upper), tick_spacing)

            if tick_lower >= tick_upper:
                tick_upper = tick_lower + tick_spacing

            actual_lower = tick_to_price(tick_lower)
            actual_upper = tick_to_price(tick_upper)

            # Estimate fee APY from pool TVL and fee rate
            try:
                t0_contract = w3.eth.contract(address=Web3.to_checksum_address(token0), abi=ERC20_ABI)
                t1_contract = w3.eth.contract(address=Web3.to_checksum_address(token1), abi=ERC20_ABI)
                t0_bal = t0_contract.functions.balanceOf(pool_addr).call()
                t1_bal = t1_contract.functions.balanceOf(pool_addr).call()
                t0_dec = t0_contract.functions.decimals().call()
                t1_dec = t1_contract.functions.decimals().call()

                # Very rough TVL estimate (assuming stablecoin/ETH pair)
                pool_tvl = (t0_bal / 10**t0_dec) + (t1_bal / 10**t1_dec) * current_price
                fee_rate = int(fee) / 1_000_000  # fee in decimal

                # Fee APY: assume capital efficiency of 10x for concentrated positions
                if pool_tvl > 0 and pool_liq > 0:
                    daily_volume_estimate = pool_tvl * 2  # rough heuristic
                    annual_fees = daily_volume_estimate * fee_rate * 365
                    estimated_apy = (annual_fees / pool_tvl) * 10  # 10x capital efficiency
                    estimated_apy_str = f"{min(estimated_apy * 100, 9999):.1f}"
                else:
                    estimated_apy_str = "N/A"
            except:
                estimated_apy_str = "N/A"

            {
                "current_price": f"{current_price:.6f}",
                "suggested_price_lower": f"{actual_lower:.6f}",
                "suggested_price_upper": f"{actual_upper:.6f}",
                "suggested_tick_lower": tick_lower,
                "suggested_tick_upper": tick_upper,
                "volatility_1d": f"{vol_1d:.4f}",
                "range_width_pct": f"{(actual_upper / actual_lower - 1) * 100:.1f}",
                "estimated_fee_apy": estimated_apy_str,
                "pool_address": pool_addr,
                "pool_liquidity": str(pool_liq),
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
        current_price: result["current_price"],
        suggested_price_lower: result["suggested_price_lower"],
        suggested_price_upper: result["suggested_price_upper"],
        suggested_tick_lower: result["suggested_tick_lower"],
        suggested_tick_upper: result["suggested_tick_upper"],
        volatility_1d: result["volatility_1d"],
        range_width_pct: result["range_width_pct"],
        estimated_fee_apy: result["estimated_fee_apy"],
        pool_address: result["pool_address"],
        pool_liquidity: result["pool_liquidity"],
        status: result["status"]
      }}
    end
  end
end

  def focus(_input, _agent), do: {:error, "token0 and token1 are required"}
