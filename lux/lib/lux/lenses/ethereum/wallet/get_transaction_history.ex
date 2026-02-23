defmodule Lux.Lenses.Ethereum.Wallet.GetTransactionHistory do
  @moduledoc """
  A lens for retrieving the transaction history of an Ethereum address.

  Uses the Etherscan API to return recent transactions for an address,
  including sent/received ETH transfers and internal transactions.

  ## Examples

      iex> GetTransactionHistory.focus(%{
      ...>   address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
      ...>   limit: 10,
      ...>   network: "mainnet"
      ...> }, %{agent: %{name: "TestAgent"}})
      {:ok, %{
        address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        transactions: [
          %{
            hash: "0x...",
            from: "0x...",
            to: "0x...",
            value_eth: "0.5",
            timestamp: 1_700_000_000,
            block_number: 18_000_000,
            status: "success",
            gas_used: 21000
          }
        ],
        total: 10,
        network: "mainnet"
      }}
  """

  use Lux.Lens,
    name: "Get Transaction History",
    description: "Retrieves recent transaction history for an Ethereum address via Etherscan API",
    schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Ethereum address to fetch history for"
        },
        limit: %{
          type: :integer,
          description: "Maximum number of transactions to return (1-100)",
          minimum: 1,
          maximum: 100,
          default: 20
        },
        network: %{
          type: :string,
          description: "EVM network (Etherscan-supported)",
          enum: ["mainnet", "sepolia", "base", "polygon", "arbitrum", "optimism"],
          default: "mainnet"
        },
        start_block: %{
          type: :integer,
          description: "Start block for history scan (default: 0)",
          default: 0
        }
      },
      required: ["address"]
    }

  require Logger

  alias Lux.Config

  @etherscan_apis %{
    "mainnet" => "https://api.etherscan.io/api",
    "sepolia" => "https://api-sepolia.etherscan.io/api",
    "base" => "https://api.basescan.org/api",
    "polygon" => "https://api.polygonscan.com/api",
    "arbitrum" => "https://api.arbiscan.io/api",
    "optimism" => "https://api-optimistic.etherscan.io/api"
  }

  @impl true
  def focus(input, _agent) do
    address = Map.get(input, :address, "")
    network = Map.get(input, :network, "mainnet")
    limit = Map.get(input, :limit, 20)
    start_block = Map.get(input, :start_block, 0)

    plug = Map.get(input, :plug)

    with {:ok, api_url} <- resolve_api_url(network),
         {:ok, txs} <- fetch_history(address, api_url, limit, start_block, plug) do
      {:ok, %{
        address: address,
        transactions: txs,
        total: length(txs),
        network: network
      }}
    end
  end

  defp resolve_api_url(network) do
    case Map.fetch(@etherscan_apis, network) do
      {:ok, url} -> {:ok, url}
      :error -> {:error, "Unsupported network: #{network}"}
    end
  end

  defp fetch_history(address, api_url, limit, start_block, plug \\ nil) do
    api_key = Config.etherscan_api_key()

    params = %{
      module: "account",
      action: "txlist",
      address: address,
      startblock: start_block,
      endblock: 99_999_999,
      page: 1,
      offset: limit,
      sort: "desc",
      apikey: api_key
    }

    req_opts =
      if plug do
        [plug: plug]
      else
        []
      end

    query_string = URI.encode_query(params)
    url = "#{api_url}?#{query_string}"

    case Req.get(url, req_opts) do
      {:ok, %{status: 200, body: %{"status" => "1", "result" => txs}}} ->
        {:ok, Enum.map(txs, &format_tx/1)}

      {:ok, %{status: 200, body: %{"status" => "0", "message" => msg, "result" => result}}} ->
        # "No transactions found" is a valid empty result
        if String.contains?(msg, "No transactions") or result == [] do
          {:ok, []}
        else
          {:error, "Etherscan error: #{msg}"}
        end

      {:ok, %{status: status}} ->
        {:error, "Etherscan returned HTTP #{status}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp format_tx(tx) do
    value_wei = String.to_integer(tx["value"] || "0")
    value_eth = value_wei / 1.0e18

    %{
      hash: tx["hash"],
      from: tx["from"],
      to: tx["to"],
      value_eth: :erlang.float_to_binary(value_eth, decimals: 18) |> String.trim_trailing("0") |> String.trim_trailing("."),
      timestamp: String.to_integer(tx["timeStamp"] || "0"),
      block_number: String.to_integer(tx["blockNumber"] || "0"),
      status: if(tx["txreceipt_status"] == "1", do: "success", else: "failed"),
      gas_used: String.to_integer(tx["gasUsed"] || "0")
    }
  end
end
