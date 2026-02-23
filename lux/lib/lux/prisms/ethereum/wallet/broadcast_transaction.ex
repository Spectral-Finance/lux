defmodule Lux.Prisms.Ethereum.Wallet.BroadcastTransaction do
  @moduledoc """
  A prism for broadcasting a signed Ethereum transaction to the network.

  Takes a raw signed transaction hex (from SignTransaction) and submits it
  to an EVM-compatible node via the configured RPC endpoint.

  ## Examples

      iex> BroadcastTransaction.handler(%{
      ...>   raw_transaction: "0x02f86f0180843b9aca008504a817c800825208...",
      ...>   network: "mainnet"
      ...> }, %{agent: %{name: "TestAgent"}})
      {:ok, %{
        transaction_hash: "0xabc123...",
        network: "mainnet",
        broadcasted: true
      }}
  """

  use Lux.Prism,
    name: "Broadcast Ethereum Transaction",
    description: "Broadcasts a signed transaction to an EVM-compatible network",
    input_schema: %{
      type: :object,
      properties: %{
        raw_transaction: %{
          type: :string,
          description: "Signed transaction hex (output from SignTransaction)"
        },
        network: %{
          type: :string,
          description: "Target network",
          enum: ["mainnet", "sepolia", "base", "polygon", "arbitrum", "optimism", "test"],
          default: "mainnet"
        },
        rpc_url: %{
          type: :string,
          description: "Custom RPC URL (overrides network preset if provided)"
        }
      },
      required: ["raw_transaction"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        transaction_hash: %{
          type: :string,
          description: "Transaction hash returned by the node"
        },
        network: %{
          type: :string,
          description: "Network the transaction was broadcast to"
        },
        broadcasted: %{
          type: :boolean,
          description: "Whether the broadcast was successful"
        }
      },
      required: ["transaction_hash", "network", "broadcasted"]
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

    with {:ok, raw_tx} <- validate_raw_tx(input),
         {:ok, rpc_url} <- resolve_rpc_url(input, network),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("web3"),
         {:ok, result} <- send_raw_transaction(raw_tx, rpc_url, network) do
      Logger.info("Agent #{agent_name} broadcast tx #{result["transaction_hash"]} on #{network}")
      {:ok, %{
        transaction_hash: result["transaction_hash"],
        network: network,
        broadcasted: true
      }}
    else
      {:ok, %{"success" => false, "error" => err}} ->
        {:error, "Failed to import web3: #{err}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_raw_tx(%{raw_transaction: tx}) when is_binary(tx) and byte_size(tx) > 2,
    do: {:ok, tx}
  defp validate_raw_tx(_), do: {:error, "raw_transaction is required"}

  defp resolve_rpc_url(%{rpc_url: url}, _network) when is_binary(url) and url != "",
    do: {:ok, url}
  defp resolve_rpc_url(_, "test"), do: {:ok, "test"}
  defp resolve_rpc_url(_, network) do
    api_key = Config.alchemy_api_key()
    case Map.fetch(@networks, network) do
      {:ok, base_url} -> {:ok, base_url <> api_key}
      :error -> {:error, "Unknown network: #{network}. Use rpc_url for custom networks."}
    end
  end

  defp send_raw_transaction(raw_tx, rpc_url, network) do
    result =
      python variables: %{raw_tx: raw_tx, rpc_url: rpc_url, network: network} do
        ~PY"""
        from web3 import Web3

        try:
            if network == "test" or rpc_url == "test":
                w3 = Web3(Web3.EthereumTesterProvider())
            else:
                w3 = Web3(Web3.HTTPProvider(rpc_url))

            if not w3.is_connected():
                raise Exception("Failed to connect to Ethereum node")

            # Normalize hex
            tx_bytes = bytes.fromhex(raw_tx[2:] if raw_tx.startswith("0x") else raw_tx)
            tx_hash = w3.eth.send_raw_transaction(tx_bytes)

            {"transaction_hash": tx_hash.hex(), "broadcasted": True}
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
