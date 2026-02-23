defmodule Lux.Prisms.UniswapV3.UniswapV3RebalancePrism do
  @moduledoc """
  A prism for rebalancing a Uniswap V3 concentrated liquidity position.

  Checks if the current price has moved outside the position's range. If out of
  range, removes all liquidity and creates a new position centered around the
  current price with the same width as the original range.

  ## Example

      iex> Lux.Prisms.UniswapV3.UniswapV3RebalancePrism.run(%{
      ...>   token_id: 123456,
      ...>   range_width_bps: 2000
      ...> })
      {:ok, %{
        rebalanced: true,
        old_token_id: 123456,
        new_token_id: 123789,
        old_price_lower: "1800.0",
        old_price_upper: "2200.0",
        new_price_lower: "1920.0",
        new_price_upper: "2560.0",
        current_price: "2240.0",
        tx_hash: "0xabc...",
        gas_used: 600000,
        status: "success"
      }}

  If the position is in range, returns `rebalanced: false` without transacting.

  The prism reads authentication from config:
  - :uniswap_v3_private_key — Ethereum private key for signing
  - :uniswap_v3_rpc_url — Ethereum JSON-RPC endpoint URL
  """

  use Lux.Prism,
    name: "Uniswap V3 Rebalance Position",
    description: "Rebalances a Uniswap V3 position when price moves out of range, creating a new centered position",
    input_schema: %{
      type: :object,
      properties: %{
        token_id: %{
          type: :integer,
          description: "NFT token ID of the position to rebalance"
        },
        range_width_bps: %{
          type: :integer,
          description: "New range width in basis points above/below current price (e.g. 2000 = ±10% from current price)",
          default: 2000,
          minimum: 100,
          maximum: 50000
        },
        slippage_bps: %{
          type: :integer,
          description: "Max slippage in basis points (e.g. 100 = 1%)",
          default: 100,
          minimum: 0,
          maximum: 5000
        },
        deadline_seconds: %{
          type: :integer,
          description: "Transaction deadline from now in seconds",
          default: 1200,
          minimum: 60
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
        }
      },
      required: ["token_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        rebalanced: %{type: :boolean, description: "Whether rebalancing was performed"},
        old_token_id: %{type: :integer, description: "Original position NFT token ID"},
        new_token_id: %{type: :integer, description: "New position NFT token ID (if rebalanced)"},
        old_price_lower: %{type: :string, description: "Previous position lower price bound"},
        old_price_upper: %{type: :string, description: "Previous position upper price bound"},
        new_price_lower: %{type: :string, description: "New position lower price bound"},
        new_price_upper: %{type: :string, description: "New position upper price bound"},
        current_price: %{type: :string, description: "Current pool price at time of rebalance"},
        tx_hash: %{type: :string, description: "Transaction hash (if rebalanced)"},
        gas_used: %{type: :integer, description: "Gas consumed"},
        status: %{type: :string, description: "Operation result"}
      },
      required: ["rebalanced", "old_token_id", "current_price", "status"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python
  require Logger

  @default_position_manager "0xC36442b4a4522E871399CD717aBDD847Ab11FE88"
  @default_factory "0x1F98431c8aD98523631AE4a59f267346ea31F984"
  @default_rpc "https://eth.llamarpc.com"

  def handler(%{token_id: token_id} = input, _ctx) do
    range_width_bps = Map.get(input, :range_width_bps, 2000)
    slippage = Map.get(input, :slippage_bps, 100)
    deadline_secs = Map.get(input, :deadline_seconds, 1200)
    position_manager = Map.get(input, :position_manager_address, @default_position_manager)
    factory = Map.get(input, :factory_address, @default_factory)

    Logger.info("Uniswap V3 rebalance check: tokenId=#{token_id}")

    with {:ok, private_key} <- get_config(:uniswap_v3_private_key, "UNISWAP_V3_PRIVATE_KEY"),
         {:ok, rpc_url} <- {:ok, get_rpc_url()},
         {:ok, result} <- rebalance(rpc_url, private_key, position_manager, factory,
                                    token_id, range_width_bps, slippage, deadline_secs) do
      {:ok, result}
    else
      {:error, :missing_config, key} -> {:error, "Missing configuration: #{key}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_config(config_key, env_key) do
    case Config.get(config_key) do
      nil ->
        case System.get_env(env_key) do
          nil -> {:error, :missing_config, env_key}
          val -> {:ok, val}
        end
      val -> {:ok, val}
    end
  rescue
    _ ->
      case System.get_env(env_key) do
        nil -> {:error, :missing_config, env_key}
        val -> {:ok, val}
      end
  end

  defp get_rpc_url do
    case Config.get(:uniswap_v3_rpc_url) do
      nil -> System.get_env("UNISWAP_V3_RPC_URL") || @default_rpc
      url -> url
    end
  rescue
    _ -> System.get_env("UNISWAP_V3_RPC_URL") || @default_rpc
  end

  defp rebalance(rpc_url, private_key, position_manager, factory, token_id,
                 range_width_bps, slippage_bps, deadline_secs) do
    result =
      python variables: %{
               rpc_url: rpc_url,
               private_key: private_key,
               position_manager: position_manager,
               factory: factory,
               token_id: token_id,
               range_width_bps: range_width_bps,
               slippage_bps: slippage_bps,
               deadline_seconds: deadline_secs
             } do
        ~PY"""
        import math
        import time
        from web3 import Web3
        from eth_account import Account

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
            ]},
            {"name": "decreaseLiquidity", "type": "function", "inputs": [
                {"name": "params", "type": "tuple", "components": [
                    {"name": "tokenId", "type": "uint256"},
                    {"name": "liquidity", "type": "uint128"},
                    {"name": "amount0Min", "type": "uint256"},
                    {"name": "amount1Min", "type": "uint256"},
                    {"name": "deadline", "type": "uint256"}
                ]}
            ], "outputs": [
                {"name": "amount0", "type": "uint256"},
                {"name": "amount1", "type": "uint256"}
            ]},
            {"name": "collect", "type": "function", "inputs": [
                {"name": "params", "type": "tuple", "components": [
                    {"name": "tokenId", "type": "uint256"},
                    {"name": "recipient", "type": "address"},
                    {"name": "amount0Max", "type": "uint128"},
                    {"name": "amount1Max", "type": "uint128"}
                ]}
            ], "outputs": [
                {"name": "amount0", "type": "uint256"},
                {"name": "amount1", "type": "uint256"}
            ]},
            {"name": "mint", "type": "function", "inputs": [
                {"name": "params", "type": "tuple", "components": [
                    {"name": "token0", "type": "address"},
                    {"name": "token1", "type": "address"},
                    {"name": "fee", "type": "uint24"},
                    {"name": "tickLower", "type": "int24"},
                    {"name": "tickUpper", "type": "int24"},
                    {"name": "amount0Desired", "type": "uint256"},
                    {"name": "amount1Desired", "type": "uint256"},
                    {"name": "amount0Min", "type": "uint256"},
                    {"name": "amount1Min", "type": "uint256"},
                    {"name": "recipient", "type": "address"},
                    {"name": "deadline", "type": "uint256"}
                ]}
            ], "outputs": [
                {"name": "tokenId", "type": "uint256"},
                {"name": "liquidity", "type": "uint128"},
                {"name": "amount0", "type": "uint256"},
                {"name": "amount1", "type": "uint256"}
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
            {"name": "approve", "type": "function",
             "inputs": [{"name": "spender", "type": "address"}, {"name": "amount", "type": "uint256"}],
             "outputs": [{"name": "", "type": "bool"}]},
            {"name": "allowance", "type": "function",
             "inputs": [{"name": "owner", "type": "address"}, {"name": "spender", "type": "address"}],
             "outputs": [{"name": "", "type": "uint256"}]}
        ]

        MAX_UINT128 = (2**128) - 1
        FEE_TO_TICK_SPACING = {100: 1, 500: 10, 3000: 60, 10000: 200}

        def tick_to_price(tick):
            return 1.0001 ** tick

        def price_to_tick(price):
            return math.floor(math.log(float(price)) / math.log(1.0001))

        def nearest_usable_tick(tick, tick_spacing):
            rounded = round(tick / tick_spacing) * tick_spacing
            return rounded

        def sqrt_price_to_price(sqrt_price_x96):
            ratio = (sqrt_price_x96 / (2**96)) ** 2
            return ratio

        try:
            w3 = Web3(Web3.HTTPProvider(rpc_url))
            account = Account.from_key(private_key)
            pm = Web3.to_checksum_address(position_manager)
            fact = Web3.to_checksum_address(factory)
            tid = int(token_id)

            pm_contract = w3.eth.contract(address=pm, abi=POSITION_MANAGER_ABI)
            factory_contract = w3.eth.contract(address=fact, abi=FACTORY_ABI)

            # Get position details
            pos = pm_contract.functions.positions(tid).call()
            token0 = pos[2]
            token1 = pos[3]
            fee_tier = pos[4]
            tick_lower = pos[5]
            tick_upper = pos[6]
            liquidity = pos[7]

            price_lower = tick_to_price(tick_lower)
            price_upper = tick_to_price(tick_upper)

            # Get current pool price
            pool_addr = factory_contract.functions.getPool(token0, token1, fee_tier).call()
            if pool_addr == "0x0000000000000000000000000000000000000000":
                raise ValueError(f"Pool not found for {token0}/{token1} fee={fee_tier}")

            pool_contract = w3.eth.contract(address=Web3.to_checksum_address(pool_addr), abi=POOL_ABI)
            slot0 = pool_contract.functions.slot0().call()
            current_tick = slot0[1]
            current_price = tick_to_price(current_tick)

            in_range = tick_lower <= current_tick <= tick_upper

            result = {
                "rebalanced": False,
                "old_token_id": tid,
                "new_token_id": None,
                "old_price_lower": f"{price_lower:.6f}",
                "old_price_upper": f"{price_upper:.6f}",
                "new_price_lower": None,
                "new_price_upper": None,
                "current_price": f"{current_price:.6f}",
                "tx_hash": None,
                "gas_used": 0,
                "status": "in_range"
            }

            if in_range:
                return result

            # Out of range — rebalance
            tick_spacing = FEE_TO_TICK_SPACING.get(fee_tier, 60)
            half_width = range_width_bps / 20000.0  # as fraction
            new_lower_price = current_price * (1 - half_width)
            new_upper_price = current_price * (1 + half_width)
            new_tick_lower = nearest_usable_tick(price_to_tick(new_lower_price), tick_spacing)
            new_tick_upper = nearest_usable_tick(price_to_tick(new_upper_price), tick_spacing)
            if new_tick_lower >= new_tick_upper:
                new_tick_upper = new_tick_lower + tick_spacing

            nonce = w3.eth.get_transaction_count(account.address)
            gas_price = w3.eth.gas_price
            deadline = int(time.time()) + deadline_seconds
            total_gas = 0
            last_tx = None

            # Step 1: Decrease all liquidity
            if liquidity > 0:
                dec_params = (tid, liquidity, 0, 0, deadline)
                dec_tx = pm_contract.functions.decreaseLiquidity(dec_params).build_transaction({
                    "from": account.address, "nonce": nonce,
                    "gas": 300000, "gasPrice": gas_price
                })
                signed = account.sign_transaction(dec_tx)
                dec_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
                dec_receipt = w3.eth.wait_for_transaction_receipt(dec_hash, timeout=180)
                total_gas += dec_receipt.gasUsed
                last_tx = dec_hash.hex()
                nonce += 1

            # Step 2: Collect all tokens
            collect_params = (tid, account.address, MAX_UINT128, MAX_UINT128)
            col_tx = pm_contract.functions.collect(collect_params).build_transaction({
                "from": account.address, "nonce": nonce,
                "gas": 200000, "gasPrice": gas_price
            })
            signed = account.sign_transaction(col_tx)
            col_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
            col_receipt = w3.eth.wait_for_transaction_receipt(col_hash, timeout=180)
            total_gas += col_receipt.gasUsed
            last_tx = col_hash.hex()
            nonce += 1

            # Parse collected amounts
            collected0 = 0
            collected1 = 0
            COLLECT_TOPIC = "0x70935338e69775456a85ddef226c395fb668b63fa0115f5f20610b388e6ca9c0"
            for log in col_receipt.logs:
                if len(log.topics) > 0 and log.topics[0].hex() == COLLECT_TOPIC:
                    raw = log.data.hex() if isinstance(log.data, bytes) else log.data.replace("0x", "")
                    data_bytes = bytes.fromhex(raw.replace("0x", ""))
                    if len(data_bytes) >= 64:
                        collected0 = int.from_bytes(data_bytes[0:32], "big")
                        collected1 = int.from_bytes(data_bytes[32:64], "big")
                    break

            # Step 3: Approve and mint new position
            slippage_factor = (10000 - slippage_bps) / 10000
            for addr, amt in [(token0, collected0), (token1, collected1)]:
                if amt > 0:
                    token_contract = w3.eth.contract(address=addr, abi=ERC20_ABI)
                    allowance = token_contract.functions.allowance(account.address, pm).call()
                    if allowance < amt:
                        approve_tx = token_contract.functions.approve(pm, amt).build_transaction({
                            "from": account.address, "nonce": nonce,
                            "gas": 60000, "gasPrice": gas_price
                        })
                        signed = account.sign_transaction(approve_tx)
                        approve_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
                        w3.eth.wait_for_transaction_receipt(approve_hash, timeout=120)
                        total_gas += 60000
                        nonce += 1

            new_token_id = 0
            if collected0 > 0 or collected1 > 0:
                mint_params = (
                    token0, token1, fee_tier,
                    new_tick_lower, new_tick_upper,
                    collected0, collected1,
                    int(collected0 * slippage_factor),
                    int(collected1 * slippage_factor),
                    account.address, deadline
                )
                mint_tx = pm_contract.functions.mint(mint_params).build_transaction({
                    "from": account.address, "nonce": nonce,
                    "gas": 500000, "gasPrice": gas_price
                })
                signed = account.sign_transaction(mint_tx)
                mint_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
                mint_receipt = w3.eth.wait_for_transaction_receipt(mint_hash, timeout=180)
                total_gas += mint_receipt.gasUsed
                last_tx = mint_hash.hex()

                INCREASE_TOPIC = "0x3067048beee31b25b2f1681f88dac838c8bba36af25bfb2b7cf7473a5847e35"
                for log in mint_receipt.logs:
                    if len(log.topics) > 0 and log.topics[0].hex() == INCREASE_TOPIC:
                        new_token_id = int(log.topics[1].hex(), 16)
                        break

            result["rebalanced"] = True
            result["new_token_id"] = new_token_id
            result["new_price_lower"] = f"{tick_to_price(new_tick_lower):.6f}"
            result["new_price_upper"] = f"{tick_to_price(new_tick_upper):.6f}"
            result["tx_hash"] = last_tx
            result["gas_used"] = total_gas
            result["status"] = "success"
            return result

        except Exception as e:
            {"error": str(e)}
        """
      end

    if Map.has_key?(result, "error") do
      {:error, result["error"]}
    else
      {:ok, %{
        rebalanced: result["rebalanced"],
        old_token_id: result["old_token_id"],
        new_token_id: result["new_token_id"],
        old_price_lower: result["old_price_lower"],
        old_price_upper: result["old_price_upper"],
        new_price_lower: result["new_price_lower"],
        new_price_upper: result["new_price_upper"],
        current_price: result["current_price"],
        tx_hash: result["tx_hash"],
        gas_used: result["gas_used"],
        status: result["status"]
      }}
    end
  end
end
