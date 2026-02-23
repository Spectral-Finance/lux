defmodule Lux.Lenses.UniswapV3.UniswapV3PoolLens do
  @moduledoc """
  A lens for fetching comprehensive metrics for a Uniswap V3 pool.

  Returns current price, tick, liquidity, fee tier, and TVL estimates.
  Supports pool lookup by address or by token pair + fee tier.

  ## Example

      iex> Lux.Lenses.UniswapV3.UniswapV3PoolLens.focus(%{
      ...>   token0: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      ...>   token1: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
      ...>   fee: 3000
      ...> })
      {:ok, %{
        pool_address: "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
        token0: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        token1: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
        fee_tier: 3000,
        current_tick: 200123,
        current_price: "2150.456789",
        sqrt_price_x96: "3689348814741910323",
        pool_liquidity: "5400000000000000000000",
        status: "success"
      }}
  """

  use Lux.Lens,
    name: "Uniswap V3 Pool Info",
    description: "Fetches current price, tick, liquidity, and pool metrics for a Uniswap V3 pool",
    schema: %{
      type: :object,
      properties: %{
        pool_address: %{
          type: :string,
          description: "Direct pool contract address (alternative to token pair lookup)",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        token0: %{
          type: :string,
          description: "Address of token0 (for factory lookup, ignored if pool_address provided)",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        token1: %{
          type: :string,
          description: "Address of token1 (for factory lookup, ignored if pool_address provided)",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        fee: %{
          type: :integer,
          description: "Fee tier for factory lookup: 100, 500, 3000, or 10000",
          enum: [100, 500, 3000, 10000]
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
      }
    }

  import Lux.Python
  require Lux.Python
  require Logger

  @default_factory "0x1F98431c8aD98523631AE4a59f267346ea31F984"
  @default_rpc "https://eth.llamarpc.com"

  @impl true
  def focus(input, _agent) do
    factory = Map.get(input, :factory_address, @default_factory)
    rpc_url = Map.get(input, :rpc_url, System.get_env("UNISWAP_V3_RPC_URL") || @default_rpc)
    pool_address = Map.get(input, :pool_address, nil)
    token0 = Map.get(input, :token0, nil)
    token1 = Map.get(input, :token1, nil)
    fee = Map.get(input, :fee, 3000)

    cond do
      is_nil(pool_address) and (is_nil(token0) or is_nil(token1)) ->
        {:error, "Provide either pool_address or token0+token1+fee"}
      true ->
        Logger.info("Uniswap V3 pool lens: pool=#{pool_address || "#{token0}/#{token1} #{fee}"}")
        fetch_pool_info(rpc_url, factory, pool_address, token0, token1, fee)
    end
  end

  defp fetch_pool_info(rpc_url, factory, pool_address, token0, token1, fee) do
    result =
      python variables: %{
               rpc_url: rpc_url,
               factory: factory,
               pool_address_input: pool_address,
               token0_input: token0,
               token1_input: token1,
               fee_input: fee
             } do
        ~PY"""
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
            {"name": "token0", "type": "function", "inputs": [], "outputs": [
                {"name": "", "type": "address"}
            ]},
            {"name": "token1", "type": "function", "inputs": [], "outputs": [
                {"name": "", "type": "address"}
            ]},
            {"name": "fee", "type": "function", "inputs": [], "outputs": [
                {"name": "", "type": "uint24"}
            ]}
        ]

        ERC20_ABI = [
            {"name": "balanceOf", "type": "function",
             "inputs": [{"name": "account", "type": "address"}],
             "outputs": [{"name": "", "type": "uint256"}]},
            {"name": "decimals", "type": "function", "inputs": [], "outputs": [{"name": "", "type": "uint8"}]},
            {"name": "symbol", "type": "function", "inputs": [], "outputs": [{"name": "", "type": "string"}]}
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

        try:
            w3 = Web3(Web3.HTTPProvider(rpc_url))

            if pool_address_input:
                pool_addr = Web3.to_checksum_address(pool_address_input)
            else:
                fact = Web3.to_checksum_address(factory)
                factory_contract = w3.eth.contract(address=fact, abi=FACTORY_ABI)
                pool_addr = factory_contract.functions.getPool(
                    Web3.to_checksum_address(token0_input),
                    Web3.to_checksum_address(token1_input),
                    int(fee_input)
                ).call()
                if pool_addr == "0x0000000000000000000000000000000000000000":
                    raise ValueError(f"Pool not found for {token0_input}/{token1_input} fee={fee_input}")

            pool_contract = w3.eth.contract(address=pool_addr, abi=POOL_ABI)

            slot0 = pool_contract.functions.slot0().call()
            pool_liq = pool_contract.functions.liquidity().call()
            t0_addr = pool_contract.functions.token0().call()
            t1_addr = pool_contract.functions.token1().call()
            fee_tier = pool_contract.functions.fee().call()

            sqrt_price_x96 = slot0[0]
            current_tick = slot0[1]
            current_price = tick_to_price(current_tick)

            # Get token metadata
            t0_contract = w3.eth.contract(address=t0_addr, abi=ERC20_ABI)
            t1_contract = w3.eth.contract(address=t1_addr, abi=ERC20_ABI)

            try:
                t0_symbol = t0_contract.functions.symbol().call()
                t0_decimals = t0_contract.functions.decimals().call()
                t0_balance = t0_contract.functions.balanceOf(pool_addr).call()
            except:
                t0_symbol, t0_decimals, t0_balance = "TOKEN0", 18, 0

            try:
                t1_symbol = t1_contract.functions.symbol().call()
                t1_decimals = t1_contract.functions.decimals().call()
                t1_balance = t1_contract.functions.balanceOf(pool_addr).call()
            except:
                t1_symbol, t1_decimals, t1_balance = "TOKEN1", 18, 0

            {
                "pool_address": pool_addr,
                "token0": t0_addr,
                "token0_symbol": t0_symbol,
                "token0_decimals": t0_decimals,
                "token1": t1_addr,
                "token1_symbol": t1_symbol,
                "token1_decimals": t1_decimals,
                "fee_tier": fee_tier,
                "current_tick": current_tick,
                "current_price": f"{current_price:.6f}",
                "sqrt_price_x96": str(sqrt_price_x96),
                "pool_liquidity": str(pool_liq),
                "token0_balance": str(t0_balance),
                "token1_balance": str(t1_balance),
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
        pool_address: result["pool_address"],
        token0: result["token0"],
        token0_symbol: result["token0_symbol"],
        token0_decimals: result["token0_decimals"],
        token1: result["token1"],
        token1_symbol: result["token1_symbol"],
        token1_decimals: result["token1_decimals"],
        fee_tier: result["fee_tier"],
        current_tick: result["current_tick"],
        current_price: result["current_price"],
        sqrt_price_x96: result["sqrt_price_x96"],
        pool_liquidity: result["pool_liquidity"],
        token0_balance: result["token0_balance"],
        token1_balance: result["token1_balance"],
        status: result["status"]
      }}
    end
  end
end

