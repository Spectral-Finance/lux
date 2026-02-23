defmodule Lux.Prisms.Curve.CurveClaimRewardsPrism do
  @moduledoc """
  A prism for claiming CRV and bonus token rewards from a Curve gauge.

  After staking LP tokens in a gauge, CRV rewards accrue continuously.
  This prism claims accumulated CRV (and any extra reward tokens) to the wallet.

  ## Example

      iex> Lux.Prisms.Curve.CurveClaimRewardsPrism.run(%{
      ...>   gauge_address: "0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A"
      ...> })
      {:ok, %{
        gauge_address: "0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A",
        crv_claimed: "125000000000000000000",
        tx_hash: "0xghi...",
        gas_used: 120000,
        status: "success"
      }}

  The prism reads authentication from config:
  - :curve_private_key — Ethereum private key
  - :curve_rpc_url — Ethereum JSON-RPC endpoint URL
  """

  use Lux.Prism,
    name: "Curve Claim Rewards",
    description: "Claims accumulated CRV rewards and bonus tokens from a Curve gauge",
    input_schema: %{
      type: :object,
      properties: %{
        gauge_address: %{
          type: :string,
          description: "Curve gauge contract address",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        claim_extra_rewards: %{
          type: :boolean,
          description: "Also claim any extra reward tokens (SNX, LDO, etc.) if supported",
          default: true
        }
      },
      required: ["gauge_address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        gauge_address: %{type: :string, description: "Gauge contract address"},
        crv_claimed: %{type: :string, description: "CRV tokens claimed (in wei)"},
        tx_hash: %{type: :string, description: "Transaction hash"},
        gas_used: %{type: :integer, description: "Gas consumed"},
        status: %{type: :string, description: "Operation result"}
      },
      required: ["gauge_address", "tx_hash", "status"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python
  require Logger

  @crv_minter_address "0xd061D61a4d941c39E5453435B6345Dc261C2fcE0"

  def handler(%{gauge_address: gauge_address} = input, _ctx) do
    claim_extra = Map.get(input, :claim_extra_rewards, true)
    Logger.info("Claiming CRV rewards from gauge #{gauge_address}")

    with {:ok, private_key} <- get_config(:curve_private_key, "CURVE_PRIVATE_KEY"),
         {:ok, rpc_url} <- get_config(:curve_rpc_url, "CURVE_RPC_URL"),
         {:ok, result} <- claim_rewards(rpc_url, private_key, gauge_address, claim_extra, @crv_minter_address) do
      Logger.info("Claimed rewards from #{gauge_address}: #{inspect(result)}")
      {:ok, Map.put(result, :gauge_address, gauge_address)}
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

  defp claim_rewards(rpc_url, private_key, gauge_address, claim_extra, crv_minter) do
    result =
      python variables: %{
               rpc_url: rpc_url,
               private_key: private_key,
               gauge_address: gauge_address,
               claim_extra_rewards: claim_extra,
               crv_minter_address: crv_minter
             } do
        ~PY"""
        from web3 import Web3
        from eth_account import Account

        MINTER_ABI = [
            {"name": "mint", "type": "function",
             "inputs": [{"name": "gauge_addr", "type": "address"}],
             "outputs": []}
        ]

        GAUGE_ABI = [
            {"name": "claim_rewards", "type": "function",
             "inputs": [],
             "outputs": []},
            {"name": "claimable_tokens", "type": "function",
             "inputs": [{"name": "addr", "type": "address"}],
             "outputs": [{"name": "", "type": "uint256"}]},
            {"name": "claimable_reward", "type": "function",
             "inputs": [{"name": "addr", "type": "address"}, {"name": "token", "type": "address"}],
             "outputs": [{"name": "", "type": "uint256"}]}
        ]

        CRV_TOKEN = "0xD533a949740bb3306d119CC777fa900bA034cd52"

        try:
            w3 = Web3(Web3.HTTPProvider(rpc_url))
            account = Account.from_key(private_key)
            gauge_addr = Web3.to_checksum_address(gauge_address)
            gauge = w3.eth.contract(address=gauge_addr, abi=GAUGE_ABI)
            nonce = w3.eth.get_transaction_count(account.address)
            gas_price = w3.eth.gas_price

            # Get claimable CRV before claiming
            try:
                claimable_crv = gauge.functions.claimable_tokens(account.address).call()
            except Exception:
                claimable_crv = 0

            # Mint CRV via the CRV Minter contract
            minter = w3.eth.contract(
                address=Web3.to_checksum_address(crv_minter_address),
                abi=MINTER_ABI
            )
            tx = minter.functions.mint(gauge_addr).build_transaction({
                "from": account.address,
                "nonce": nonce,
                "gas": 200000,
                "gasPrice": gas_price
            })
            signed = account.sign_transaction(tx)
            tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
            receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=180)

            # Optionally claim extra rewards
            if claim_extra_rewards:
                try:
                    nonce += 1
                    extra_tx = gauge.functions.claim_rewards().build_transaction({
                        "from": account.address,
                        "nonce": nonce,
                        "gas": 150000,
                        "gasPrice": gas_price
                    })
                    signed_extra = account.sign_transaction(extra_tx)
                    extra_hash = w3.eth.send_raw_transaction(signed_extra.raw_transaction)
                    w3.eth.wait_for_transaction_receipt(extra_hash, timeout=120)
                except Exception:
                    pass  # Not all gauges support extra rewards

            {
                "crv_claimed": str(claimable_crv),
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
        crv_claimed: result["crv_claimed"],
        tx_hash: result["tx_hash"],
        gas_used: result["gas_used"],
        status: result["status"]
      }}
    end
  end
end
