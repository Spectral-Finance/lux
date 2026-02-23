defmodule Lux.Prisms.Curve.CurveStakeGaugePrism do
  @moduledoc """
  A prism for staking and unstaking Curve LP tokens in a Curve gauge.

  Staking LP tokens in a gauge earns CRV token rewards over time.
  Use action "stake" to deposit and "unstake" to withdraw.

  ## Example — stake LP tokens

      iex> Lux.Prisms.Curve.CurveStakeGaugePrism.run(%{
      ...>   gauge_address: "0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A",
      ...>   amount: "1000000000000000000000",
      ...>   action: "stake"
      ...> })
      {:ok, %{
        gauge_address: "0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A",
        action: "stake",
        amount: "1000000000000000000000",
        tx_hash: "0xabc...",
        gas_used: 150000,
        status: "success"
      }}

  ## Example — unstake LP tokens

      iex> Lux.Prisms.Curve.CurveStakeGaugePrism.run(%{
      ...>   gauge_address: "0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A",
      ...>   amount: "500000000000000000000",
      ...>   action: "unstake"
      ...> })

  The prism reads authentication from config:
  - :curve_private_key — Ethereum private key
  - :curve_rpc_url — Ethereum JSON-RPC endpoint URL
  """

  use Lux.Prism,
    name: "Curve Stake Gauge",
    description: "Stakes or unstakes Curve LP tokens in a Curve gauge to earn CRV rewards",
    input_schema: %{
      type: :object,
      properties: %{
        gauge_address: %{
          type: :string,
          description: "Curve gauge contract address",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        amount: %{
          type: :string,
          description: "Amount of LP tokens to stake/unstake (in wei)"
        },
        action: %{
          type: :string,
          description: "Operation: 'stake' (deposit) or 'unstake' (withdraw)",
          enum: ["stake", "unstake"]
        },
        lp_token_address: %{
          type: :string,
          description: "LP token contract address. Required for staking to approve allowance.",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["gauge_address", "amount", "action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        gauge_address: %{type: :string, description: "Gauge contract address"},
        action: %{type: :string, description: "Operation performed"},
        amount: %{type: :string, description: "LP token amount (in wei)"},
        tx_hash: %{type: :string, description: "Transaction hash"},
        gas_used: %{type: :integer, description: "Gas consumed"},
        status: %{type: :string, description: "Operation result"}
      },
      required: ["gauge_address", "action", "amount", "tx_hash", "status"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python
  require Logger

  def handler(%{gauge_address: gauge_address, amount: amount, action: action} = input, _ctx) do
    lp_token_address = Map.get(input, :lp_token_address, nil)
    Logger.info("#{action} #{amount} LP tokens in gauge #{gauge_address}")

    with {:ok, private_key} <- get_config(:curve_private_key, "CURVE_PRIVATE_KEY"),
         {:ok, rpc_url} <- get_config(:curve_rpc_url, "CURVE_RPC_URL"),
         {:ok, result} <- stake_gauge(rpc_url, private_key, gauge_address, amount, action, lp_token_address) do
      Logger.info("#{action} complete for gauge #{gauge_address}: #{inspect(result)}")
      {:ok, result |> Map.put(:gauge_address, gauge_address) |> Map.put(:action, action) |> Map.put(:amount, amount)}
    else
      {:error, :missing_config, key} ->
        {:error, "Missing configuration: #{key}"}
      {:error, reason} ->
        {:error, reason}
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

  defp stake_gauge(rpc_url, private_key, gauge_address, amount, action, lp_token_address) do
    result =
      python variables: %{
               rpc_url: rpc_url,
               private_key: private_key,
               gauge_address: gauge_address,
               amount: amount,
               action: action,
               lp_token_address: lp_token_address
             } do
        ~PY"""
        from web3 import Web3
        from eth_account import Account

        GAUGE_ABI = [
            {"name": "deposit", "type": "function",
             "inputs": [{"name": "_value", "type": "uint256"}],
             "outputs": []},
            {"name": "withdraw", "type": "function",
             "inputs": [{"name": "_value", "type": "uint256"}],
             "outputs": []},
            {"name": "balanceOf", "type": "function",
             "inputs": [{"name": "arg0", "type": "address"}],
             "outputs": [{"name": "", "type": "uint256"}]}
        ]

        ERC20_APPROVE_ABI = [
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
            gauge_addr = Web3.to_checksum_address(gauge_address)
            gauge = w3.eth.contract(address=gauge_addr, abi=GAUGE_ABI)
            amt = int(amount)
            nonce = w3.eth.get_transaction_count(account.address)
            gas_price = w3.eth.gas_price

            if action == "stake":
                # Approve gauge to spend LP tokens if lp_token_address provided
                if lp_token_address:
                    lp_addr = Web3.to_checksum_address(lp_token_address)
                    lp = w3.eth.contract(address=lp_addr, abi=ERC20_APPROVE_ABI)
                    allowance = lp.functions.allowance(account.address, gauge_addr).call()
                    if allowance < amt:
                        approve_tx = lp.functions.approve(gauge_addr, amt).build_transaction({
                            "from": account.address,
                            "nonce": nonce,
                            "gas": 60000,
                            "gasPrice": gas_price
                        })
                        signed_approve = account.sign_transaction(approve_tx)
                        approve_hash = w3.eth.send_raw_transaction(signed_approve.raw_transaction)
                        w3.eth.wait_for_transaction_receipt(approve_hash, timeout=120)
                        nonce += 1

                tx = gauge.functions.deposit(amt).build_transaction({
                    "from": account.address,
                    "nonce": nonce,
                    "gas": 200000,
                    "gasPrice": gas_price
                })
            else:
                tx = gauge.functions.withdraw(amt).build_transaction({
                    "from": account.address,
                    "nonce": nonce,
                    "gas": 200000,
                    "gasPrice": gas_price
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
