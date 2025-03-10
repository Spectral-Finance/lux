defmodule Lux.Lenses.Etherscan.GetLogs do
  @moduledoc """
  Lens for fetching event logs from an address with optional filtering by block range from the Etherscan API.

  ## Examples

  ```elixir
  # Get event logs for an address with block range (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.GetLogs.focus(%{
    address: "0xbd3531da5cf5857e7cfaa92426877b022e612cf8",
    fromBlock: 12878196,
    toBlock: 12878196
  })

  # Get event logs for an address with block range and pagination
  Lux.Lenses.Etherscan.GetLogs.focus(%{
    address: "0xbd3531da5cf5857e7cfaa92426877b022e612cf8",
    fromBlock: 12878196,
    toBlock: 12878196,
    page: 1,
    offset: 1000,
    chainid: 1
  })

  # Get event logs filtered by topics
  Lux.Lenses.Etherscan.GetLogs.focus(%{
    fromBlock: 12878196,
    toBlock: 12879196,
    topic0: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
    topic0_1_opr: "and",
    topic1: "0x0000000000000000000000000000000000000000000000000000000000000000"
  })

  # Get event logs by address filtered by topics
  Lux.Lenses.Etherscan.GetLogs.focus(%{
    address: "0x59728544b08ab483533076417fbbb2fd0b17ce3a",
    fromBlock: 15073139,
    toBlock: 15074139,
    topic0: "0x27c4f0403323142b599832f26acd21c74a9e5b809f2215726e244a4ac588cd7d",
    topic0_1_opr: "and",
    topic1: "0x00000000000000000000000023581767a106ae21c074b2276d25e5c3e136a68b"
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.GetLogs",
    description: "Retrieves blockchain event logs with powerful filtering by address, block range, and event topics",
    url: "https://api.etherscan.io/v2/api",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Base.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{
        chainid: %{
          type: :integer,
          description: "Network identifier (1=Ethereum, 137=Polygon, 56=BSC, etc.)",
          default: 1
        },
        address: %{
          type: :string,
          description: "Contract address to filter logs from (optional if filtering by topics only)",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        fromBlock: %{
          type: :integer,
          description: "Starting block height to search for logs (inclusive)"
        },
        toBlock: %{
          type: :integer,
          description: "Ending block height to search for logs (inclusive)"
        },
        page: %{
          type: :integer,
          description: "Page number for paginated results (starts at 1)",
          default: 1
        },
        offset: %{
          type: :integer,
          description: "Number of log records to return per page (maximum 1000)",
          default: 1000
        },
        topic0: %{
          type: :string,
          description: "Event signature hash or indexed parameter to filter by (first topic position)"
        },
        topic1: %{
          type: :string,
          description: "First indexed parameter to filter by (second topic position)"
        },
        topic2: %{
          type: :string,
          description: "Second indexed parameter to filter by (third topic position)"
        },
        topic3: %{
          type: :string,
          description: "Third indexed parameter to filter by (fourth topic position)"
        },
        topic0_1_opr: %{
          type: :string,
          description: "Logical operator between topic0 and topic1 (and=both required, or=either accepted)",
          enum: ["and", "or"]
        },
        topic0_2_opr: %{
          type: :string,
          description: "Logical operator between topic0 and topic2 (and=both required, or=either accepted)",
          enum: ["and", "or"]
        },
        topic0_3_opr: %{
          type: :string,
          description: "Logical operator between topic0 and topic3 (and=both required, or=either accepted)",
          enum: ["and", "or"]
        },
        topic1_2_opr: %{
          type: :string,
          description: "Logical operator between topic1 and topic2 (and=both required, or=either accepted)",
          enum: ["and", "or"]
        },
        topic1_3_opr: %{
          type: :string,
          description: "Logical operator between topic1 and topic3 (and=both required, or=either accepted)",
          enum: ["and", "or"]
        },
        topic2_3_opr: %{
          type: :string,
          description: "Logical operator between topic2 and topic3 (and=both required, or=either accepted)",
          enum: ["and", "or"]
        }
      },
      required: ["fromBlock", "toBlock"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Set module and action for this endpoint
    params
    |> Map.put(:module, "logs")
    |> Map.put(:action, "getLogs")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_list(result) ->
        # Process the list of event logs
        processed_results = Enum.map(result, fn log ->
          %{
            address: Map.get(log, "address", ""),
            topics: Map.get(log, "topics", []),
            data: Map.get(log, "data", ""),
            block_number: Map.get(log, "blockNumber", ""),
            timestamp: Map.get(log, "timeStamp", ""),
            gas_price: Map.get(log, "gasPrice", ""),
            gas_used: Map.get(log, "gasUsed", ""),
            log_index: Map.get(log, "logIndex", ""),
            transaction_hash: Map.get(log, "transactionHash", ""),
            transaction_index: Map.get(log, "transactionIndex", "")
          }
        end)

        # Return a structured response
        {:ok, %{
          result: processed_results
        }}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end
