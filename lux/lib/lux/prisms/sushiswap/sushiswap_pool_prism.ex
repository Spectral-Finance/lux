defmodule Lux.Prisms.Sushiswap.SushiswapPoolPrism do
  @moduledoc """
  Manages SushiSwap V2 liquidity pools across multiple chains.

  ## Example

      iex> Lux.Prisms.Sushiswap.SushiswapPoolPrism.run(%{
      ...>   action: "get_reserves",
      ...>   token_a: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
      ...>   token_b: "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56",
      ...>   chain_id: 56
      ...> })
      {:ok, %{status: "success", reserve_a: "...", reserve_b: "..."}}
  """

  use Lux.Prism,
    name: "SushiSwap Pool Manager",
    description: "Manages SushiSwap V2 liquidity pools — reserves, add/remove liquidity",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action: get_reserves | add_liquidity | remove_liquidity",
          enum: ["get_reserves", "add_liquidity", "remove_liquidity"]
        },
        token_a: %{type: :string, description: "Token A address"},
        token_b: %{type: :string, description: "Token B address"},
        amount_a: %{type: :string, description: "Amount A in wei (for add_liquidity)"},
        amount_b: %{type: :string, description: "Amount B in wei (for add_liquidity)"},
        liquidity: %{type: :string, description: "LP token amount (for remove_liquidity)"},
        slippage: %{type: :integer, description: "Slippage bps", default: 50},
        chain_id: %{type: :integer, default: 56}
      },
      required: ["action", "token_a", "token_b"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        reserve_a: %{type: :string},
        reserve_b: %{type: :string},
        pair_address: %{type: :string},
        tx_hash: %{type: :string}
      },
      required: ["status"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python

  @factories %{
    1     => "0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac",
    56    => "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
    137   => "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
    42_161 => "0xc35DADB65012eC5796536bD9864eD8773aBc74C4"
  }

  @routers %{
    1     => "0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9f",
    56    => "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
    137   => "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
    42_161 => "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506"
  }

  @rpcs %{
    1   => "https://eth.llamarpc.com",
    56  => "https://bsc-dataseed.binance.org/",
    137 => "https://polygon-rpc.com",
    42_161 => "https://arb1.arbitrum.io/rpc"
  }

  def handler(input, _ctx) do
    chain_id = input[:chain_id] || input["chain_id"] || 56
    action   = input[:action]   || input["action"]
    token_a  = input[:token_a]  || input["token_a"]
    token_b  = input[:token_b]  || input["token_b"]
    factory  = @factories[chain_id] || @factories[56]
    router   = @routers[chain_id]   || @routers[56]
    rpc_url  = @rpcs[chain_id]      || @rpcs[56]

    with {:ok, private_key} <- get_private_key(),
         {:ok, result} <- execute_action(
           action, private_key, rpc_url,
           %{factory: factory, router: router, token_a: token_a, token_b: token_b, input: input}
         ) do
      {:ok, result}
    else
      {:error, :missing_key} -> {:error, "Private key not configured"}
      {:error, reason}       -> {:error, reason}
    end
  end

  defp get_private_key do
    key = Config.get(:sushiswap_private_key) ||
          Config.get(:web3_private_key) ||
          System.get_env("PRIVATE_KEY")
    if key, do: {:ok, key}, else: {:error, :missing_key}
  rescue
    _ -> {:error, :missing_key}
  end

  defp execute_action(action, private_key, rpc_url, ctx) do
    %{factory: factory, router: router, token_a: token_a, token_b: token_b, input: input} = ctx
    %{slippage: slippage, amount_a: amount_a, amount_b: amount_b, liquidity: liquidity} =
      extract_action_params(input)

    result =
      python variables: %{
        action:     action,
        private_key: private_key,
        rpc_url:    rpc_url,
        factory:    factory,
        router:     router,
        token_a:    token_a,
        token_b:    token_b,
        amount_a:   amount_a,
        amount_b:   amount_b,
        liquidity:  liquidity,
        slippage:   slippage
      } do
        ~PY"""
        from web3 import Web3
        from web3.middleware import ExtraDataToPOAMiddleware
        import time

        w3 = Web3(Web3.HTTPProvider(rpc_url))
        w3.middleware_onion.inject(ExtraDataToPOAMiddleware, layer=0)

        account   = w3.eth.account.from_key(private_key)
        token_a_c = Web3.to_checksum_address(token_a)
        token_b_c = Web3.to_checksum_address(token_b)

        FACTORY_ABI = [{
          "inputs": [
            {"name": "tokenA", "type": "address"},
            {"name": "tokenB", "type": "address"}
          ],
          "name": "getPair",
          "outputs": [{"name": "pair", "type": "address"}],
          "stateMutability": "view",
          "type": "function"
        }]

        PAIR_ABI = [{
          "inputs": [],
          "name": "getReserves",
          "outputs": [
            {"name": "_reserve0", "type": "uint112"},
            {"name": "_reserve1", "type": "uint112"},
            {"name": "_blockTimestampLast", "type": "uint32"}
          ],
          "stateMutability": "view",
          "type": "function"
        },{
          "inputs": [],
          "name": "token0",
          "outputs": [{"name": "", "type": "address"}],
          "stateMutability": "view",
          "type": "function"
        },{
          "inputs": [],
          "name": "totalSupply",
          "outputs": [{"name": "", "type": "uint256"}],
          "stateMutability": "view",
          "type": "function"
        }]

        ROUTER_ABI = [
          {
            "inputs": [
              {"name": "tokenA",          "type": "address"},
              {"name": "tokenB",          "type": "address"},
              {"name": "amountADesired",  "type": "uint256"},
              {"name": "amountBDesired",  "type": "uint256"},
              {"name": "amountAMin",      "type": "uint256"},
              {"name": "amountBMin",      "type": "uint256"},
              {"name": "to",              "type": "address"},
              {"name": "deadline",        "type": "uint256"}
            ],
            "name": "addLiquidity",
            "outputs": [
              {"name": "amountA",    "type": "uint256"},
              {"name": "amountB",    "type": "uint256"},
              {"name": "liquidity",  "type": "uint256"}
            ],
            "stateMutability": "nonpayable",
            "type": "function"
          },
          {
            "inputs": [
              {"name": "tokenA",      "type": "address"},
              {"name": "tokenB",      "type": "address"},
              {"name": "liquidity",   "type": "uint256"},
              {"name": "amountAMin",  "type": "uint256"},
              {"name": "amountBMin",  "type": "uint256"},
              {"name": "to",          "type": "address"},
              {"name": "deadline",    "type": "uint256"}
            ],
            "name": "removeLiquidity",
            "outputs": [
              {"name": "amountA", "type": "uint256"},
              {"name": "amountB", "type": "uint256"}
            ],
            "stateMutability": "nonpayable",
            "type": "function"
          }
        ]

        ERC20_ABI = [
          {"inputs":[{"name":"owner","type":"address"},{"name":"spender","type":"address"}],"name":"allowance","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
          {"inputs":[{"name":"spender","type":"address"},{"name":"amount","type":"uint256"}],"name":"approve","outputs":[{"name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"}
        ]

        factory_c = w3.eth.contract(address=Web3.to_checksum_address(factory), abi=FACTORY_ABI)
        router_c  = w3.eth.contract(address=Web3.to_checksum_address(router),  abi=ROUTER_ABI)
        pair_addr = factory_c.functions.getPair(token_a_c, token_b_c).call()

        if action == "get_reserves":
          if pair_addr == "0x0000000000000000000000000000000000000000":
            {"error": "No liquidity pool found for this pair"}
          else:
            pair_c    = w3.eth.contract(address=Web3.to_checksum_address(pair_addr), abi=PAIR_ABI)
            reserves  = pair_c.functions.getReserves().call()
            token0    = pair_c.functions.token0().call()
            supply    = pair_c.functions.totalSupply().call()
            if token0.lower() == token_a_c.lower():
              r_a, r_b = reserves[0], reserves[1]
            else:
              r_a, r_b = reserves[1], reserves[0]
            {
              "status":       "success",
              "pair_address": pair_addr,
              "reserve_a":    str(r_a),
              "reserve_b":    str(r_b),
              "total_supply": str(supply)
            }

        elif action == "add_liquidity":
          amount_a_wei   = int(amount_a)
          amount_b_wei   = int(amount_b)
          amount_a_min   = amount_a_wei * (10000 - slippage) // 10000
          amount_b_min   = amount_b_wei * (10000 - slippage) // 10000
          deadline       = int(time.time()) + 300
          max_uint       = 2**256 - 1

          for token_addr in [token_a_c, token_b_c]:
            tok = w3.eth.contract(address=token_addr, abi=ERC20_ABI)
            if tok.functions.allowance(account.address, Web3.to_checksum_address(router)).call() < max_uint // 2:
              tx = tok.functions.approve(Web3.to_checksum_address(router), max_uint).build_transaction({
                "from": account.address, "gas": 100000,
                "gasPrice": w3.eth.gas_price,
                "nonce": w3.eth.get_transaction_count(account.address)
              })
              signed = account.sign_transaction(tx)
              w3.eth.send_raw_transaction(signed.raw_transaction)
              time.sleep(2)

          tx = router_c.functions.addLiquidity(
            token_a_c, token_b_c,
            amount_a_wei, amount_b_wei,
            amount_a_min, amount_b_min,
            account.address, deadline
          ).build_transaction({
            "from": account.address, "gas": 300000,
            "gasPrice": w3.eth.gas_price,
            "nonce": w3.eth.get_transaction_count(account.address)
          })
          signed  = account.sign_transaction(tx)
          tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
          receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)
          if receipt.status == 0:
            {"error": f"addLiquidity reverted: {tx_hash.hex()}"}
          else:
            {"status": "success", "tx_hash": tx_hash.hex(), "action": "add_liquidity"}

        elif action == "remove_liquidity":
          liq_wei  = int(liquidity)
          deadline = int(time.time()) + 300
          max_uint = 2**256 - 1

          lp_tok = w3.eth.contract(address=Web3.to_checksum_address(pair_addr), abi=ERC20_ABI)
          if lp_tok.functions.allowance(account.address, Web3.to_checksum_address(router)).call() < liq_wei:
            tx = lp_tok.functions.approve(Web3.to_checksum_address(router), max_uint).build_transaction({
              "from": account.address, "gas": 100000,
              "gasPrice": w3.eth.gas_price,
              "nonce": w3.eth.get_transaction_count(account.address)
            })
            signed = account.sign_transaction(tx)
            w3.eth.send_raw_transaction(signed.raw_transaction)
            time.sleep(2)

          # amountAMin/amountBMin must NOT be 0 — slippage protection
          reserves  = w3.eth.contract(address=Web3.to_checksum_address(pair_addr), abi=PAIR_ABI).functions.getReserves().call()
          supply    = w3.eth.contract(address=Web3.to_checksum_address(pair_addr), abi=PAIR_ABI).functions.totalSupply().call()
          amt_a_exp = liq_wei * reserves[0] // supply
          amt_b_exp = liq_wei * reserves[1] // supply
          amt_a_min = amt_a_exp * (10000 - slippage) // 10000
          amt_b_min = amt_b_exp * (10000 - slippage) // 10000

          tx = router_c.functions.removeLiquidity(
            token_a_c, token_b_c,
            liq_wei, amt_a_min, amt_b_min,
            account.address, deadline
          ).build_transaction({
            "from": account.address, "gas": 300000,
            "gasPrice": w3.eth.gas_price,
            "nonce": w3.eth.get_transaction_count(account.address)
          })
          signed  = account.sign_transaction(tx)
          tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
          receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)
          if receipt.status == 0:
            {"error": f"removeLiquidity reverted: {tx_hash.hex()}"}
          else:
            {"status": "success", "tx_hash": tx_hash.hex(), "action": "remove_liquidity"}
        else:
          {"error": f"Unknown action: {action}"}
        """
      end

    case result do
      %{"error" => e}          -> {:error, e}
      %{"status" => "success"} = r -> {:ok, r}
      _ -> {:error, "Unexpected response"}
    end
  end

  defp extract_action_params(input) do
    %{
      slippage: input[:slippage] || input["slippage"] || 50,
      amount_a: input[:amount_a] || input["amount_a"] || "0",
      amount_b: input[:amount_b] || input["amount_b"] || "0",
      liquidity: input[:liquidity] || input["liquidity"] || "0"
    }
  end
end
