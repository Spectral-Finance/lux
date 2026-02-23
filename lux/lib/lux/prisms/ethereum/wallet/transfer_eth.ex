defmodule Lux.Prisms.Ethereum.Wallet.TransferEth do
  @moduledoc """
  A prism for transferring ETH between accounts.

  Combines nonce retrieval, gas estimation, transaction signing, and broadcasting
  into a single operation. Supports EIP-1559 fee estimation automatically.

  ## Examples

      iex> TransferEth.handler(%{
      ...>   private_key: "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
      ...>   to: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
      ...>   amount_eth: "0.001",
      ...>   network: "sepolia"
      ...> }, %{agent: %{name: "TestAgent"}})
      {:ok, %{
        transaction_hash: "0x...",
        from: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        to: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
        amount_eth: "0.001",
        network: "sepolia"
      }}
  """

  use Lux.Prism,
    name: "Transfer ETH",
    description: "Transfers ETH from one account to another with automatic gas estimation",
    input_schema: %{
      type: :object,
      properties: %{
        private_key: %{
          type: :string,
          description: "Sender's private key (hex with 0x prefix)"
        },
        to: %{
          type: :string,
          description: "Recipient address"
        },
        amount_eth: %{
          type: :string,
          description: "Amount to transfer in ETH (e.g., '0.1')"
        },
        network: %{
          type: :string,
          description: "Target network",
          enum: ["mainnet", "sepolia", "base", "polygon", "arbitrum", "optimism", "test"],
          default: "mainnet"
        },
        rpc_url: %{
          type: :string,
          description: "Custom RPC URL (overrides network if provided)"
        }
      },
      required: ["private_key", "to", "amount_eth"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        transaction_hash: %{type: :string},
        from: %{type: :string},
        to: %{type: :string},
        amount_eth: %{type: :string},
        network: %{type: :string}
      },
      required: ["transaction_hash", "from", "to", "amount_eth", "network"]
    }

  import Lux.Python
  require Lux.Python
  require Logger

  alias Lux.Config

  @networks %{
    "mainnet" => "https://eth-mainnet.g.alchemy.com/v2/",
    "sepolia" => "https://eth-sepolia.g.alchemy.com/v2/",
    "base" => "https://base-mainnet.g.alchemy.com/v2/",
    "polygon" => "https://polygon-mainnet.g.alchemy.com/v2/",
    "arbitrum" => "https://arb-mainnet.g.alchemy.com/v2/",
    "optimism" => "https://opt-mainnet.g.alchemy.com/v2/"
  }

  def handler(input, agent) do
    agent_name = get_in(agent, [:agent, :name]) || "Unknown"
    network = Map.get(input, :network, "mainnet")

    with {:ok, private_key} <- validate_required(input, :private_key),
         {:ok, to} <- validate_required(input, :to),
         {:ok, amount_eth} <- validate_amount(input),
         {:ok, rpc_url} <- resolve_rpc(input, network),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("web3"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("eth_account"),
         {:ok, result} <- execute_transfer(private_key, to, amount_eth, rpc_url, network) do
      Logger.info("Agent #{agent_name} transferred #{amount_eth} ETH → #{to} on #{network}: #{result["transaction_hash"]}")
      {:ok, %{
        transaction_hash: result["transaction_hash"],
        from: result["from"],
        to: to,
        amount_eth: amount_eth,
        network: network
      }}
    else
      {:ok, %{"success" => false, "error" => err}} ->
        {:error, "Package import failed: #{err}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_required(input, key) do
    case Map.fetch(input, key) do
      {:ok, val} when is_binary(val) and val != "" -> {:ok, val}
      _ -> {:error, "#{key} is required"}
    end
  end

  defp validate_amount(%{amount_eth: amount}) when is_binary(amount) do
    case Float.parse(amount) do
      {val, ""} when val > 0 -> {:ok, amount}
      _ -> {:error, "amount_eth must be a positive decimal string like '0.1'"}
    end
  end
  defp validate_amount(_), do: {:error, "amount_eth is required"}

  defp resolve_rpc(%{rpc_url: url}, _) when is_binary(url) and url != "", do: {:ok, url}
  defp resolve_rpc(_, "test"), do: {:ok, "test"}
  defp resolve_rpc(_, network) do
    api_key = Config.alchemy_api_key()
    case Map.fetch(@networks, network) do
      {:ok, base} -> {:ok, base <> api_key}
      :error -> {:error, "Unknown network: #{network}"}
    end
  end

  defp execute_transfer(private_key, to, amount_eth, rpc_url, network) do
    result =
      python variables: %{
        private_key: private_key,
        to: to,
        amount_eth: amount_eth,
        rpc_url: rpc_url,
        network: network
      } do
        ~PY"""
        from web3 import Web3
        from eth_account import Account

        try:
            if network == "test" or rpc_url == "test":
                w3 = Web3(Web3.EthereumTesterProvider())
            else:
                w3 = Web3(Web3.HTTPProvider(rpc_url))

            if not w3.is_connected():
                raise Exception("Cannot connect to node")

            pk = private_key if private_key.startswith("0x") else "0x" + private_key
            acct = Account.from_key(pk)

            value_wei = w3.to_wei(amount_eth, "ether")
            nonce = w3.eth.get_transaction_count(acct.address)
            chain_id = w3.eth.chain_id

            # Try EIP-1559 fees first
            try:
                base_fee = w3.eth.get_block("latest")["baseFeePerGas"]
                priority_fee = w3.to_wei(1, "gwei")
                max_fee = base_fee * 2 + priority_fee

                tx = {
                    "to": w3.to_checksum_address(to),
                    "nonce": nonce,
                    "value": value_wei,
                    "gas": 21000,
                    "chainId": chain_id,
                    "maxFeePerGas": max_fee,
                    "maxPriorityFeePerGas": priority_fee,
                    "type": 2,
                }
            except Exception:
                # Fall back to legacy pricing
                gas_price = w3.eth.gas_price
                tx = {
                    "to": w3.to_checksum_address(to),
                    "nonce": nonce,
                    "value": value_wei,
                    "gas": 21000,
                    "chainId": chain_id,
                    "gasPrice": gas_price,
                }

            signed = Account.sign_transaction(tx, pk)
            tx_hash = w3.eth.send_raw_transaction(signed.rawTransaction)

            {"transaction_hash": tx_hash.hex(), "from": acct.address}
        except Exception as e:
            {"error": str(e)}
        """
      end

    if Map.has_key?(result, "error") do
      {:error, result["error"]}
    else
      {:ok, result}
    end
  end
end
