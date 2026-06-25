defmodule Lux.Lenses.Ethereum.SmartContract.GetEvents do
  @moduledoc """
  A lens for monitoring smart contract events on Ethereum-compatible chains.

  Queries the Etherscan API (or compatible) for contract events by topic,
  supporting real-time event monitoring, historical syncing, and multi-contract
  subscription management.

  ## Examples

      iex> GetEvents.focus(%{
      ...>   contract_address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      ...>   from_block: "latest",
      ...>   topic0: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
      ...> })
      {:ok, %{events: [...], count: N, contract_address: "0x..."}}
  """

  require Logger

  @etherscan_base "https://api.etherscan.io/api"

  use Lux.Lens,
    name: "Get Smart Contract Events",
    description: "Fetches smart contract events/logs from an Ethereum-compatible chain",
    url: @etherscan_base,
    method: :get,
    headers: [{"Accept", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        contract_address: %{
          type: :string,
          description: "Contract address to monitor (0x-prefixed)",
          pattern: "^0x[0-9a-fA-F]{40}$"
        },
        from_block: %{
          type: [:string, :integer],
          description: "Start block (number, 'latest', or 'earliest')",
          default: "latest"
        },
        to_block: %{
          type: [:string, :integer],
          description: "End block (number, 'latest')",
          default: "latest"
        },
        topic0: %{
          type: :string,
          description: "Event signature hash (keccak256 of event signature)"
        },
        topic1: %{type: :string, description: "Second topic filter (optional)"},
        page: %{type: :integer, description: "Page number", default: 1},
        offset: %{type: :integer, description: "Records per page (max 1000)", default: 100}
      },
      required: ["contract_address"]
    }

  @impl true
  def focus(%{contract_address: address} = params) do
    api_key = Application.get_env(:lux, :api_keys, [])[:etherscan] || System.get_env("ETHERSCAN_API_KEY") || ""

    query = %{
      module:  "logs",
      action:  "getLogs",
      address: address,
      fromBlock: Map.get(params, :from_block, "latest"),
      toBlock:   Map.get(params, :to_block, "latest"),
      page:    Map.get(params, :page, 1),
      offset:  Map.get(params, :offset, 100),
      apikey:  api_key
    }
    query = if Map.has_key?(params, :topic0), do: Map.put(query, :topic0, params.topic0), else: query
    query = if Map.has_key?(params, :topic1), do: Map.put(query, :topic1, params.topic1), else: query

    case Req.get(@etherscan_base, params: query, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: %{"status" => "1", "result" => logs}}} ->
        events = Enum.map(logs, &parse_log/1)
        Logger.info("Retrieved #{length(events)} events for contract #{address}")
        {:ok, %{events: events, count: length(events), contract_address: address}}

      {:ok, %{status: 200, body: %{"status" => "0", "message" => "No records found"}}} ->
        {:ok, %{events: [], count: 0, contract_address: address}}

      {:ok, %{status: 200, body: %{"status" => "0", "result" => error}}} ->
        {:error, "Etherscan API error: #{error}"}

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status} from Etherscan"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp parse_log(log) do
    %{
      address:    log["address"],
      block_number: String.to_integer(log["blockNumber"] || "0x0", 16),
      tx_hash:    log["transactionHash"],
      log_index:  log["logIndex"],
      topics:     log["topics"] || [],
      data:       log["data"],
      timestamp:  log["timeStamp"] && String.to_integer(log["timeStamp"], 16)
    }
  end
end
