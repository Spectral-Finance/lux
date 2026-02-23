defmodule Lux.Prisms.UniswapV3.UniswapV3AddLiquidityPrism do
  @moduledoc """
  A prism for adding concentrated liquidity to a Uniswap V3 pool.

  Mints a new NFT position representing concentrated liquidity within a specified
  price range. Uniswap V3 uses tick-based pricing where each tick represents a
  0.01% price increment.

  Fee tiers: 100 (0.01%), 500 (0.05%), 3000 (0.3%), 10000 (1%)

  ## Example

      iex> Lux.Prisms.UniswapV3.UniswapV3AddLiquidityPrism.run(%{
      ...>   token0: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      ...>   token1: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
      ...>   fee: 3000,
      ...>   amount0_desired: "1000000000",
      ...>   amount1_desired: "500000000000000000",
      ...>   price_lower: "1500.0",
      ...>   price_upper: "2500.0",
      ...>   slippage_bps: 50
      ...> })
      {:ok, %{
        token_id: 123456,
        liquidity: "1500000000000000000",
        amount0: "999900000",
        amount1: "499800000000000000",
        tx_hash: "0xabc...",
        gas_used: 350000,
        status: "success"
      }}

  The prism reads authentication from config:
  - :uniswap_v3_private_key — Ethereum private key for signing
  - :uniswap_v3_rpc_url — Ethereum JSON-RPC endpoint URL
  """

  use Lux.Prism,
    name: "Uniswap V3 Add Liquidity",
    description: "Mints a concentrated liquidity position on Uniswap V3 within a specified price range",
    input_schema: %{
      type: :object,
      properties: %{
        token0: %{
          type: :string,
          description: "Address of the first token (lower address)",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        token1: %{
          type: :string,
          description: "Address of the second token (higher address)",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        fee: %{
          type: :integer,
          description: "Pool fee tier: 100 (0.01%), 500 (0.05%), 3000 (0.3%), 10000 (1%)",
          enum: [100, 500, 3000, 10000]
        },
        amount0_desired: %{
          type: :string,
          description: "Desired amount of token0 to add (in wei)"
        },
        amount1_desired: %{
          type: :string,
          description: "Desired amount of token1 to add (in wei)"
        },
        price_lower: %{
          type: :string,
          description: "Lower price bound (token1 per token0, as decimal string)"
        },
        price_upper: %{
          type: :string,
          description: "Upper price bound (token1 per token0, as decimal string)"
        },
        slippage_bps: %{
          type: :integer,
          description: "Max slippage in basis points (e.g. 50 = 0.5%)",
          default: 50,
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
        }
      },
      required: ["token0", "token1", "fee", "amount0_desired", "amount1_desired", "price_lower", "price_upper"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        token_id: %{type: :integer, description: "NFT token ID of the created position"},
        liquidity: %{type: :string, description: "Liquidity amount added"},
        amount0: %{type: :string, description: "Token0 amount actually added (in wei)"},
        amount1: %{type: :string, description: "Token1 amount actually added (in wei)"},
        tx_hash: %{type: :string, description: "Transaction hash"},
        gas_used: %{type: :integer, description: "Gas consumed"},
        status: %{type: :string, description: "Operation result"}
      },
      required: ["token_id", "liquidity", "amount0", "amount1", "tx_hash", "status"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python
  require Logger

  @default_position_manager "0xC36442b4a4522E871399CD717aBDD847Ab11FE88"
  @default_rpc "https://eth.llamarpc.com"

  def handler(%{token0: token0, token1: token1, fee: fee,
                amount0_desired: amount0, amount1_desired: amount1,
                price_lower: price_lower, price_upper: price_upper} = input, _ctx) do
    slippage = Map.get(input, :slippage_bps, 50)
    deadline_secs = Map.get(input, :deadline_seconds, 1200)
    position_manager = Map.get(input, :position_manager_address, @default_position_manager)

    Logger.info("Uniswap V3 add liquidity: #{token0}/#{token1} fee=#{fee}")

    with {:ok, private_key} <- get_config(:uniswap_v3_private_key, "UNISWAP_V3_PRIVATE_KEY"),
         {:ok, rpc_url} <- {:ok, get_rpc_url()},
         {:ok, result} <- mint_position(rpc_url, private_key, position_manager,
                                        token0, token1, fee, amount0, amount1,
                                        price_lower, price_upper, slippage, deadline_secs) do
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

  defp mint_position(rpc_url, private_key, position_manager, token0, token1, fee,
                     amount0, amount1, price_lower, price_upper, slippage_bps, deadline_secs) do
    result =
      python variables: %{
               rpc_url: rpc_url,
               private_key: private_key,
               position_manager: position_manager,
               token0: token0,
               token1: token1,
               fee: fee,
               amount0_desired: amount0,
               amount1_desired: amount1,
               price_lower: price_lower,
               price_upper: price_upper,
               slippage_bps: slippage_bps,
               deadline_seconds: deadline_secs
             } do
        ~PY"""
        import math
        import time
        from web3 import Web3
        from eth_account import Account

        POSITION_MANAGER_ABI = [
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

        ERC20_ABI = [
            {"name": "approve", "type": "function",
             "inputs": [{"name": "spender", "type": "address"}, {"name": "amount", "type": "uint256"}],
             "outputs": [{"name": "", "type": "bool"}]},
            {"name": "allowance", "type": "function",
             "inputs": [{"name": "owner", "type": "address"}, {"name": "spender", "type": "address"}],
             "outputs": [{"name": "", "type": "uint256"}]}
        ]

        def price_to_tick(price):
            """Convert price (token1/token0) to Uniswap V3 tick."""
            return math.floor(math.log(float(price)) / math.log(1.0001))

        def nearest_usable_tick(tick, tick_spacing):
            """Round tick to nearest usable tick given fee tier's tick spacing."""
            rounded = round(tick / tick_spacing) * tick_spacing
            return rounded

        FEE_TO_TICK_SPACING = {100: 1, 500: 10, 3000: 60, 10000: 200}

        try:
            w3 = Web3(Web3.HTTPProvider(rpc_url))
            account = Account.from_key(private_key)
            pm = Web3.to_checksum_address(position_manager)
            addr0 = Web3.to_checksum_address(token0)
            addr1 = Web3.to_checksum_address(token1)
            amt0 = int(amount0_desired)
            amt1 = int(amount1_desired)
            fee_int = int(fee)

            tick_spacing = FEE_TO_TICK_SPACING.get(fee_int, 60)
            tick_lower = nearest_usable_tick(price_to_tick(price_lower), tick_spacing)
            tick_upper = nearest_usable_tick(price_to_tick(price_upper), tick_spacing)

            if tick_lower >= tick_upper:
                tick_lower, tick_upper = tick_upper - tick_spacing, tick_upper

            slippage_factor = (10000 - slippage_bps) / 10000
            min0 = int(amt0 * slippage_factor)
            min1 = int(amt1 * slippage_factor)
            deadline = int(time.time()) + deadline_seconds
            nonce = w3.eth.get_transaction_count(account.address)
            gas_price = w3.eth.gas_price

            # Approve position manager for both tokens
            for addr, amt in [(addr0, amt0), (addr1, amt1)]:
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
                    nonce += 1

            pm_contract = w3.eth.contract(address=pm, abi=POSITION_MANAGER_ABI)
            params = (
                addr0, addr1, fee_int,
                tick_lower, tick_upper,
                amt0, amt1,
                min0, min1,
                account.address, deadline
            )
            tx = pm_contract.functions.mint(params).build_transaction({
                "from": account.address, "nonce": nonce,
                "gas": 500000, "gasPrice": gas_price
            })
            signed = account.sign_transaction(tx)
            tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
            receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=180)

            # Decode IncreaseLiquidity event to get tokenId and amounts
            token_id = 0
            liquidity = "0"
            out0 = str(min0)
            out1 = str(min1)

            INCREASE_LIQUIDITY_TOPIC = "0x3067048beee31b25b2f1681f88dac838c8bba36af25bfb2b7cf7473a5847e35"
            for log in receipt.logs:
                if len(log.topics) > 0 and log.topics[0].hex() == INCREASE_LIQUIDITY_TOPIC:
                    token_id = int(log.topics[1].hex(), 16)
                    raw = log.data.hex() if isinstance(log.data, bytes) else log.data.lstrip("0x")
                    data_bytes = bytes.fromhex(raw.replace("0x", ""))
                    if len(data_bytes) >= 96:
                        liquidity = str(int.from_bytes(data_bytes[0:32], "big"))
                        out0 = str(int.from_bytes(data_bytes[32:64], "big"))
                        out1 = str(int.from_bytes(data_bytes[64:96], "big"))
                    break

            {
                "token_id": token_id,
                "liquidity": liquidity,
                "amount0": out0,
                "amount1": out1,
                "tx_hash": tx_hash.hex(),
                "gas_used": receipt.gasUsed,
                "status": "success" if receipt.status == 1 else "failed"
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
        liquidity: result["liquidity"],
        amount0: result["amount0"],
        amount1: result["amount1"],
        tx_hash: result["tx_hash"],
        gas_used: result["gas_used"],
        status: result["status"]
      }}
    end
  end
end
