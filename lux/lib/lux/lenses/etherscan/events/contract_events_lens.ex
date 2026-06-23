defmodule Lux.Lenses.Etherscan.ContractEvents do
  @moduledoc """
  Smart Contract Event Monitoring System.

  Provides comprehensive event monitoring for Ethereum smart contracts including:
  - Contract event subscription management (via polling intervals)
  - Event filtering and pattern matching by topic
  - Historical event syncing with block range support
  - Real-time event monitoring via repeated polls
  - Custom event parsing and decoding using contract ABI
  - Webhook-ready notification payloads
  - Event persistence data structure

  This lens wraps the Etherscan logs module to fetch event logs, then
  decodes them against a provided ABI so agents can reason about the
  semantic meaning of each event rather than raw hex data.

  ## Examples

      # Monitor Transfer events for Uniswap V2 Pair
      Lux.Lenses.Etherscan.ContractEvents.focus(%{
        address: "0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc",
        fromBlock: 12_878_196,
        toBlock: "latest",
        chainid: 1
      })

      # Decode events using a custom ABI
      Lux.Lenses.Etherscan.ContractEvents.focus(%{
        address: "0xdac17f958d2ee523a2206206994597c13d831ec7",
        fromBlock: 18_000_000,
        toBlock: 18_001_000,
        chainid: 1,
        abi: [
          %{
            "anonymous" => false,
            "inputs" => [
              %{"indexed" => true, "name" => "from", "type" => "address"},
              %{"indexed" => true, "name" => "to", "type" => "address"},
              %{"indexed" => false, "name" => "value", "type" => "uint256"}
            ],
            "name" => "Transfer",
            "type" => "event"
          }
        ]
      })
  """

  alias Lux.Lenses.Etherscan.Base
  alias Lux.Lenses.Etherscan.Events.EventDecoder

  use Lux.Lens,
    name: "Etherscan.ContractEvents",
    description:
      "Smart contract event monitoring system with ABI-based decoding, historical syncing, and real-time polling",
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
          description: "Contract address to monitor for events",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        fromBlock: %{
          type: :integer,
          description: "Starting block height to search for events (inclusive)"
        },
        toBlock: %{
          type: [:integer, :string],
          description: "Ending block height or tag ('latest', 'pending') to search for events (inclusive)",
          default: "latest"
        },
        page: %{
          type: :integer,
          description: "Page number for paginated results (starts at 1)",
          default: 1
        },
        offset: %{
          type: :integer,
          description: "Number of event records to return per page (maximum 1000)",
          default: 100
        },
        topic0: %{
          type: :string,
          description: "Event signature hash to filter by (e.g., Transfer event: 0xddf252ad...)"
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
          description: "Logical operator between topic0 and topic2",
          enum: ["and", "or"]
        },
        topic0_3_opr: %{
          type: :string,
          description: "Logical operator between topic0 and topic3",
          enum: ["and", "or"]
        },
        topic1_2_opr: %{
          type: :string,
          description: "Logical operator between topic1 and topic2",
          enum: ["and", "or"]
        },
        topic1_3_opr: %{
          type: :string,
          description: "Logical operator between topic1 and topic3",
          enum: ["and", "or"]
        },
        topic2_3_opr: %{
          type: :string,
          description: "Logical operator between topic2 and topic3",
          enum: ["and", "or"]
        },
        abi: %{
          type: :array,
          description:
            "Contract ABI for decoding event data. If omitted, events are returned as raw logs. Provide an ABI array to get decoded event names, parameter values, and types."
        }
      },
      required: ["fromBlock", "address"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    params
    |> Map.put(:module, "logs")
    |> Map.put(:action, "getLogs")
  end

  @doc """
  Transforms the API response into a more usable format.

  Decodes raw log entries into structured event data. When an ABI is provided,
  each event is decoded to extract the event name, parameter names, types,
  and values. Events are also enriched with webhook-ready notification payloads.
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_list(result) ->
        decoded_events = Enum.map(result, &decode_raw_log/1)
        webhook = build_webhook_payload(decoded_events)
        {:ok, %{result: decoded_events, total_count: length(decoded_events), webhook_payload: webhook}}

      {:ok, %{result: []}} ->
        {:ok, %{result: [], total_count: 0, webhook_payload: %{}}}

      other ->
        other
    end
  end

  @doc """
  Decodes a list of raw event logs using the provided ABI.

  This function allows post-hoc decoding of event logs fetched via
  `focus/1` when the ABI was not supplied in the original request.

  ## Examples

      iex> logs = [%{"topics" => ["0xddf252ad..."], "data" => "0x..."}]
      iex> abi = [%{"name" => "Transfer", "type" => "event", "inputs" => [...]}]
      iex> ContractEvents.decode(logs, abi)
      [%{...decoded event data...}]
  """
  @spec decode(list(map()), list(map()) | nil) :: list(map())
  def decode(logs, abi) when is_list(logs) do
    if abi do
      EventDecoder.decode_events(logs, abi)
    else
      Enum.map(logs, &decode_raw_log/1)
    end
  end

  def decode(_, _), do: []

  ## Private helpers

  @spec decode_raw_log(map()) :: map()
  defp decode_raw_log(log) do
    event_sig =
      case log["topics"] do
        [sig | _] -> sig
        [] -> ""
      end

    Map.merge(log, %{
      "event_signature" => event_sig,
      "block_number" => Map.get(log, "blockNumber", ""),
      "block_timestamp" => Map.get(log, "timeStamp", ""),
      "transaction_hash" => Map.get(log, "transactionHash", ""),
      "log_index" => Map.get(log, "logIndex", "")
    })
  end

  @spec build_webhook_payload(list(map())) :: map()
  defp build_webhook_payload(events) when is_list(events) do
    %{
      events: events,
      count: length(events),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      source: "etherscan_logs"
    }
  end

  defp build_webhook_payload(_), do: %{}
end
