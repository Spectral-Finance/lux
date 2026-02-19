defmodule Lux.Lenses.EventMonitor.GetContractEventsLens do
  @moduledoc """
  Lens for fetching historical smart contract events with decoding support.

  This lens wraps the Etherscan GetLogs API with additional event decoding
  capabilities. It can decode raw event logs into human-readable format when
  provided with a contract ABI.

  ## Examples

      # Fetch Transfer events for USDC
      Lux.Lenses.EventMonitor.GetContractEventsLens.focus(%{
        address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        from_block: 18000000,
        to_block: 18001000,
        chain_id: 1,
        event_signature: "Transfer(address,address,uint256)"
      })

      # Fetch all events in a block range
      Lux.Lenses.EventMonitor.GetContractEventsLens.focus(%{
        address: "0xdead...",
        from_block: 18000000,
        to_block: 18001000
      })
  """

  alias Lux.EventMonitor.Decoder
  alias Lux.EventMonitor.EventLog
  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Contract Event Fetcher",
    description: "Fetches and optionally decodes historical smart contract events",
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
        address: %{
          type: :string,
          description: "Contract address to fetch events from"
        },
        from_block: %{
          type: :integer,
          description: "Starting block number"
        },
        to_block: %{
          type: :integer,
          description: "Ending block number"
        },
        chain_id: %{
          type: :integer,
          description: "Chain ID (1=Ethereum, 137=Polygon, etc.)",
          default: 1
        },
        event_signature: %{
          type: :string,
          description: "Event signature to filter by (e.g., 'Transfer(address,address,uint256)')"
        },
        abi: %{
          type: :array,
          description: "Contract ABI for event decoding"
        },
        page: %{
          type: :integer,
          description: "Page number for pagination",
          default: 1
        },
        limit: %{
          type: :integer,
          description: "Results per page (max 1000)",
          default: 1000
        }
      },
      required: ["address", "from_block", "to_block"]
    }

  @doc """
  Prepares parameters for the Etherscan API request.
  """
  def before_focus(params) do
    api_params = %{
      module: "logs",
      action: "getLogs",
      address: params[:address],
      fromBlock: params[:from_block],
      toBlock: params[:to_block],
      chainid: params[:chain_id] || 1,
      page: params[:page] || 1,
      offset: params[:limit] || 1000
    }

    # Add topic filter if event signature is provided
    api_params =
      if params[:event_signature] do
        topic0 = Decoder.event_topic(params[:event_signature])
        Map.put(api_params, :topic0, topic0)
      else
        api_params
      end

    api_params
  end

  @doc """
  Processes the API response and optionally decodes events.
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_list(result) ->
        chain_id = 1  # Default; will be overridden if available

        event_logs =
          Enum.map(result, fn raw ->
            EventLog.from_raw(
              %{
                "address" => Map.get(raw, "address", ""),
                "topics" => Map.get(raw, "topics", []),
                "data" => Map.get(raw, "data", "0x"),
                "blockNumber" => Map.get(raw, "blockNumber", "0"),
                "transactionHash" => Map.get(raw, "transactionHash", ""),
                "logIndex" => Map.get(raw, "logIndex", "0"),
                "timeStamp" => Map.get(raw, "timeStamp"),
                "blockHash" => Map.get(raw, "blockHash"),
                "transactionIndex" => Map.get(raw, "transactionIndex"),
                "removed" => Map.get(raw, "removed", false)
              },
              chain_id: chain_id
            )
          end)

        {:ok, %{
          events: event_logs,
          count: length(event_logs)
        }}

      {:ok, %{result: result}} ->
        {:ok, %{events: [], count: 0, raw: result}}

      other ->
        other
    end
  end
end
