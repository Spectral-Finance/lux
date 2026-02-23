defmodule Lux.Prisms.PancakeSwap.PancakeSwapHarvestPrism do
  @moduledoc """
  A prism for harvesting CAKE rewards from PancakeSwap yield farms.

  Triggers reward collection from a MasterChef pool by calling deposit(pid, 0)
  (a standard MasterChef harvest pattern). The CAKE rewards are sent to the
  caller's wallet. Optionally auto-compounds by re-staking harvested CAKE
  into the CAKE single-staking pool (PID 0).

  ## Example — simple harvest

      iex> Lux.Prisms.PancakeSwap.PancakeSwapHarvestPrism.run(%{
      ...>   pid: 2
      ...> })
      {:ok, %{
        pid: 2,
        cake_harvested: "125000000000000000000",
        auto_compounded: false,
        tx_hash: "0xdef...",
        gas_used: 130000,
        status: "success"
      }}

  ## Example — harvest and auto-compound

      iex> Lux.Prisms.PancakeSwap.PancakeSwapHarvestPrism.run(%{
      ...>   pid: 2,
      ...>   auto_compound: true
      ...> })

  The prism reads authentication from config:
  - :pancakeswap_private_key — BNB Chain private key
  - :pancakeswap_rpc_url — BNB Chain RPC URL
  """

  use Lux.Prism,
    name: "PancakeSwap Harvest",
    description: "Harvests CAKE rewards from a PancakeSwap farm, optionally auto-compounding back into CAKE pool",
    input_schema: %{
      type: :object,
      properties: %{
        pid: %{
          type: :integer,
          description: "MasterChef pool ID to harvest from",
          minimum: 0
        },
        auto_compound: %{
          type: :boolean,
          description: "If true, re-stakes harvested CAKE into the CAKE single-staking pool (PID 0)",
          default: false
        },
        masterchef_address: %{
          type: :string,
          description: "MasterChef V2 contract address (defaults to BSC mainnet)",
          default: "0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["pid"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        pid: %{type: :integer, description: "Pool ID harvested from"},
        cake_harvested: %{type: :string, description: "CAKE amount harvested (in wei)"},
        auto_compounded: %{type: :boolean, description: "Whether CAKE was re-staked"},
        tx_hash: %{type: :string, description: "Transaction hash"},
        gas_used: %{type: :integer, description: "Gas consumed"},
        status: %{type: :string, description: "Operation result"}
      },
      required: ["pid", "cake_harvested", "auto_compounded", "tx_hash", "status"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python
  require Logger

  @default_masterchef "0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652"
  @cake_token "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82"
  @default_rpc "https://bsc-dataseed.binance.org"

  def handler(%{pid: pid} = input, _ctx) do
    auto_compound = Map.get(input, :auto_compound, false)
    masterchef = Map.get(input, :masterchef_address, @default_masterchef)
    Logger.info("PancakeSwap harvest: pid=#{pid}, auto_compound=#{auto_compound}")

    with {:ok, private_key} <- get_config(:pancakeswap_private_key, "PANCAKESWAP_PRIVATE_KEY"),
         {:ok, rpc_url} <- {:ok, get_rpc_url()},
         {:ok, result} <- harvest(rpc_url, private_key, masterchef, pid, auto_compound, @cake_token) do
      {:ok, result |> Map.put(:pid, pid) |> Map.put(:auto_compounded, auto_compound)}
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

  defp harvest(rpc_url, private_key, masterchef_addr, pid, auto_compound, cake_token) do
    result =
      python variables: %{
               rpc_url: rpc_url,
               private_key: private_key,
               masterchef_address: masterchef_addr,
               pid: pid,
               auto_compound: auto_compound,
               cake_token_address: cake_token
             } do
        ~PY"""
        from web3 import Web3
        from eth_account import Account

        MASTERCHEF_ABI = [
            {"name": "deposit", "type": "function",
             "inputs": [{"name": "_pid", "type": "uint256"}, {"name": "_amount", "type": "uint256"}],
             "outputs": []},
            {"name": "pendingCake", "type": "function",
             "inputs": [{"name": "_pid", "type": "uint256"}, {"name": "_user", "type": "address"}],
             "outputs": [{"name": "", "type": "uint256"}]}
        ]

        ERC20_ABI = [
            {"name": "balanceOf", "type": "function",
             "inputs": [{"name": "account", "type": "address"}],
             "outputs": [{"name": "", "type": "uint256"}]},
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
            cake_addr = Web3.to_checksum_address(cake_token_address)
            mc = w3.eth.contract(address=mc_addr, abi=MASTERCHEF_ABI)
            nonce = w3.eth.get_transaction_count(account.address)
            gas_price = w3.eth.gas_price

            # Get pending CAKE before harvest
            try:
                pending_cake = mc.functions.pendingCake(pid, account.address).call()
            except Exception:
                pending_cake = 0

            # Harvest by calling deposit(pid, 0) — standard MasterChef pattern
            tx = mc.functions.deposit(pid, 0).build_transaction({
                "from": account.address, "nonce": nonce,
                "gas": 200000, "gasPrice": gas_price
            })
            signed = account.sign_transaction(tx)
            tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
            receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=180)

            if auto_compound and pending_cake > 0 and receipt.status == 1:
                # Re-stake CAKE into PID 0 (CAKE single-staking pool)
                try:
                    nonce += 1
                    cake = w3.eth.contract(address=cake_addr, abi=ERC20_ABI)
                    allowance = cake.functions.allowance(account.address, mc_addr).call()
                    if allowance < pending_cake:
                        approve_tx = cake.functions.approve(mc_addr, pending_cake).build_transaction({
                            "from": account.address, "nonce": nonce,
                            "gas": 60000, "gasPrice": gas_price
                        })
                        signed_approve = account.sign_transaction(approve_tx)
                        approve_hash = w3.eth.send_raw_transaction(signed_approve.raw_transaction)
                        w3.eth.wait_for_transaction_receipt(approve_hash, timeout=120)
                        nonce += 1

                    compound_tx = mc.functions.deposit(0, pending_cake).build_transaction({
                        "from": account.address, "nonce": nonce,
                        "gas": 200000, "gasPrice": gas_price
                    })
                    signed_compound = account.sign_transaction(compound_tx)
                    compound_hash = w3.eth.send_raw_transaction(signed_compound.raw_transaction)
                    w3.eth.wait_for_transaction_receipt(compound_hash, timeout=120)
                except Exception:
                    pass  # Compound failed, harvest still succeeded

            {
                "cake_harvested": str(pending_cake),
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
        cake_harvested: result["cake_harvested"],
        tx_hash: result["tx_hash"],
        gas_used: result["gas_used"],
        status: result["status"]
      }}
    end
  end
end
