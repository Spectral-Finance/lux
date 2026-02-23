defmodule Lux.Lenses.Ethereum.Wallet.GetTransactionStatus do
  @moduledoc """
  A lens for retrieving the status and receipt of an Ethereum transaction.

  Returns transaction details including confirmation status, gas used,
  block number, and whether the transaction succeeded or reverted.

  ## Examples

      iex> GetTransactionStatus.focus(%{
      ...>   transaction_hash: "0xabc123...",
      ...>   network: "mainnet"
      ...> }, %{agent: %{name: "TestAgent"}})
      {:ok, %{
        transaction_hash: "0xabc123...",
        status: "success",
        block_number: 19_000_000,
        confirmations: 12,
        gas_used: 21000,
        from: "0x...",
        to: "0x...",
        value_eth: "0.1"
      }}
  """

  use Lux.Lens,
    name: "Get Transaction Status",
    description: "Retrieves the status, receipt, and details of an Ethereum transaction",
    schema: %{
      type: :object,
      properties: %{
        transaction_hash: %{
          type: :string,
          description: "Transaction hash (0x-prefixed hex)"
        },
        network: %{
          type: :string,
          description: "EVM network",
          enum: ["mainnet", "sepolia", "base", "polygon", "arbitrum", "optimism", "test"],
          default: "mainnet"
        },
        rpc_url: %{
          type: :string,
          description: "Custom RPC URL"
        }
      },
      required: ["transaction_hash"]
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

  @impl true
  def focus(input, _agent) do
    tx_hash = Map.get(input, :transaction_hash, "")
    network = Map.get(input, :network, "mainnet")

    with {:ok, rpc_url} <- resolve_rpc(input, network),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("web3"),
         {:ok, result} <- fetch_tx_status(tx_hash, rpc_url, network) do
      {:ok, result}
    else
      {:ok, %{"success" => false, "error" => err}} ->
        {:error, "Failed to import web3: #{err}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_rpc(%{rpc_url: url}, _) when is_binary(url) and url != "", do: {:ok, url}
  defp resolve_rpc(_, "test"), do: {:ok, "test"}
  defp resolve_rpc(_, network) do
    api_key = Config.alchemy_api_key()
    case Map.fetch(@networks, network) do
      {:ok, base} -> {:ok, base <> api_key}
      :error -> {:error, "Unknown network: #{network}"}
    end
  end

  defp fetch_tx_status(tx_hash, rpc_url, network) do
    result =
      python variables: %{tx_hash: tx_hash, rpc_url: rpc_url, network: network} do
        ~PY"""
        from web3 import Web3

        try:
            if network == "test" or rpc_url == "test":
                w3 = Web3(Web3.EthereumTesterProvider())
            else:
                w3 = Web3(Web3.HTTPProvider(rpc_url))

            if not w3.is_connected():
                raise Exception("Cannot connect to node")

            # Fetch receipt (None if not mined yet)
            receipt = w3.eth.get_transaction_receipt(tx_hash)
            tx = w3.eth.get_transaction(tx_hash)

            if receipt is None:
                return {
                    "transaction_hash": tx_hash,
                    "status": "pending",
                    "block_number": None,
                    "confirmations": 0,
                    "gas_used": None,
                    "from": tx["from"] if tx else None,
                    "to": tx.get("to") if tx else None,
                    "value_eth": str(float(Web3.from_wei(tx["value"], "ether"))) if tx else "0",
                    "network": network
                }

            current_block = w3.eth.block_number
            confirmations = current_block - receipt["blockNumber"] if receipt["blockNumber"] else 0
            value_eth = str(float(Web3.from_wei(tx["value"], "ether"))) if tx else "0"

            {
                "transaction_hash": tx_hash,
                "status": "success" if receipt["status"] == 1 else "reverted",
                "block_number": receipt["blockNumber"],
                "confirmations": confirmations,
                "gas_used": receipt["gasUsed"],
                "from": receipt["from"],
                "to": receipt.get("to"),
                "value_eth": value_eth,
                "network": network
            }
        except Exception as e:
            {"error": str(e)}
        """
      end

    if Map.has_key?(result, "error") do
      {:error, result["error"]}
    else
      {:ok, %{
        transaction_hash: result["transaction_hash"],
        status: result["status"],
        block_number: result["block_number"],
        confirmations: result["confirmations"],
        gas_used: result["gas_used"],
        from: result["from"],
        to: result["to"],
        value_eth: result["value_eth"],
        network: result["network"]
      }}
    end
  end
end
