defmodule Lux.Prisms.PancakeSwap.PancakeSwapFarmPrism do
  @moduledoc """
  A prism for staking and unstaking LP tokens in PancakeSwap MasterChef yield farms.

  MasterChef V2 manages all PancakeSwap yield farms. Each pool has a `pid` (pool ID).
  Staking earns CAKE token rewards continuously.

  ## Example — stake LP tokens

      iex> Lux.Prisms.PancakeSwap.PancakeSwapFarmPrism.run(%{
      ...>   pid: 2,
      ...>   amount: "1000000000000000000000",
      ...>   action: "stake",
      ...>   lp_token_address: "0x0eD7e52944161450477ee417DE9Cd3a859b14fD0"
      ...> })
      {:ok, %{
        pid: 2,
        action: "stake",
        amount: "1000000000000000000000",
        tx_hash: "0xabc...",
        gas_used: 200000,
        status: "success"
      }}

  ## Example — unstake LP tokens

      iex> Lux.Prisms.PancakeSwap.PancakeSwapFarmPrism.run(%{
      ...>   pid: 2,
      ...>   amount: "500000000000000000000",
      ...>   action: "unstake"
      ...> })

  Common PIDs (BSC mainnet):
  - PID 0: CAKE staking pool
  - PID 2: CAKE-BNB LP
  - PID 3: BUSD-BNB LP
  - PID 252: CAKE-USDT LP (V2)

  The prism reads authentication from config:
  - :pancakeswap_private_key — BNB Chain private key
  - :pancakeswap_rpc_url — BNB Chain RPC URL
  """

  use Lux.Prism,
    name: "PancakeSwap Farm",
    description: "Stakes or unstakes LP tokens in PancakeSwap MasterChef yield farms to earn CAKE",
    input_schema: %{
      type: :object,
      properties: %{
        pid: %{
          type: :integer,
          description: "MasterChef pool ID (pid). Find at pancakeswap.finance/farms.",
          minimum: 0
        },
        amount: %{
          type: :string,
          description: "Amount of LP tokens to stake/unstake (in wei)"
        },
        action: %{
          type: :string,
          description: "Operation: 'stake' to deposit or 'unstake' to withdraw",
          enum: ["stake", "unstake"]
        },
        lp_token_address: %{
          type: :string,
          description: "LP token contract address. Required for staking (needed for approval).",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        masterchef_address: %{
          type: :string,
          description: "MasterChef V2 contract address (defaults to BSC mainnet)",
          default: "0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["pid", "amount", "action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        pid: %{type: :integer, description: "Pool ID"},
        action: %{type: :string, description: "Operation performed"},
        amount: %{type: :string, description: "LP amount processed (in wei)"},
        tx_hash: %{type: :string, description: "Transaction hash"},
        gas_used: %{type: :integer, description: "Gas consumed"},
        status: %{type: :string, description: "Operation result"}
      },
      required: ["pid", "action", "amount", "tx_hash", "status"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python
  require Logger

  @default_masterchef "0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652"
  @default_rpc "https://bsc-dataseed.binance.org"

  def handler(%{pid: pid, amount: amount, action: action} = input, _ctx) do
    lp_token = Map.get(input, :lp_token_address, nil)
    masterchef = Map.get(input, :masterchef_address, @default_masterchef)
    Logger.info("PancakeSwap farm #{action}: pid=#{pid}, amount=#{amount}")

    with {:ok, private_key} <- get_config(:pancakeswap_private_key, "PANCAKESWAP_PRIVATE_KEY"),
         {:ok, rpc_url} <- {:ok, get_rpc_url()},
         {:ok, result} <- farm(rpc_url, private_key, masterchef, pid, amount, action, lp_token) do
      {:ok, result |> Map.put(:pid, pid) |> Map.put(:action, action) |> Map.put(:amount, amount)}
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
    case Config.get(:pancakeswap_rpc_url) do
      nil -> System.get_env("PANCAKESWAP_RPC_URL") || @default_rpc
      url -> url
    end
  rescue
    _ -> System.get_env("PANCAKESWAP_RPC_URL") || @default_rpc
  end

  defp farm(rpc_url, private_key, masterchef_addr, pid, amount, action, lp_token_address) do
    result =
      python variables: %{
               rpc_url: rpc_url,
               private_key: private_key,
               masterchef_address: masterchef_addr,
               pid: pid,
               amount: amount,
               action: action,
               lp_token_address: lp_token_address
             } do
        ~PY"""
        from web3 import Web3
        from eth_account import Account

        MASTERCHEF_ABI = [
            {"name": "deposit", "type": "function",
             "inputs": [{"name": "_pid", "type": "uint256"}, {"name": "_amount", "type": "uint256"}],
             "outputs": []},
            {"name": "withdraw", "type": "function",
             "inputs": [{"name": "_pid", "type": "uint256"}, {"name": "_amount", "type": "uint256"}],
             "outputs": []}
        ]

        ERC20_ABI = [
            {"name": "approve", "type": "function",
             "inputs": [{"name": "_spender", "type": "address"}, {"name": "_value", "type": "uint256"}],
             "outputs": [{"name": "", "type": "bool"}]},
            {"name": "allowance", "type": "function",
             "inputs": [{"name": "owner", "type": "address"}, {"name": "spender", "type": "address"}],
             "outputs": [{"name": "", "type": "uint256"}]}
        ]

        try:
            w3 = Web3(Web3.HTTPProvider(rpc_url))
            account = Account.from_key(private_key)
            mc_addr = Web3.to_checksum_address(masterchef_address)
            mc = w3.eth.contract(address=mc_addr, abi=MASTERCHEF_ABI)
            amt = int(amount)
            nonce = w3.eth.get_transaction_count(account.address)
            gas_price = w3.eth.gas_price

            if action == "stake":
                # Approve MasterChef if needed
                if lp_token_address:
                    lp_addr = Web3.to_checksum_address(lp_token_address)
                    lp = w3.eth.contract(address=lp_addr, abi=ERC20_ABI)
                    allowance = lp.functions.allowance(account.address, mc_addr).call()
                    if allowance < amt:
                        approve_tx = lp.functions.approve(mc_addr, amt).build_transaction({
                            "from": account.address, "nonce": nonce,
                            "gas": 60000, "gasPrice": gas_price
                        })
                        signed_approve = account.sign_transaction(approve_tx)
                        approve_hash = w3.eth.send_raw_transaction(signed_approve.raw_transaction)
                        w3.eth.wait_for_transaction_receipt(approve_hash, timeout=120)
                        nonce += 1

                tx = mc.functions.deposit(pid, amt).build_transaction({
                    "from": account.address, "nonce": nonce,
                    "gas": 250000, "gasPrice": gas_price
                })
            else:
                tx = mc.functions.withdraw(pid, amt).build_transaction({
                    "from": account.address, "nonce": nonce,
                    "gas": 250000, "gasPrice": gas_price
                })

            signed = account.sign_transaction(tx)
            tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
            receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=180)

            {
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
        tx_hash: result["tx_hash"],
        gas_used: result["gas_used"],
        status: result["status"]
      }}
    end
  end
end
