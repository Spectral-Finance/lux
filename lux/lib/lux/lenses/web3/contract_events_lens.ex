defmodule Lux.Lenses.Web3.ContractEventsLens do
  @moduledoc """
  A Lux Lens for querying historical smart contract events.

  Provides a high-level interface for agents to query past contract events
  from the EventMonitor's stored data or directly from the blockchain.

  ## Schema

  Input:
    * `subscription_id` – the subscription ID to query events from (optional)
    * `contract_address` – contract address to query (required if no subscription_id)
    * `event_signatures` – list of event signature strings to filter by
    * `from_block` – start block number for historical query
    * `to_block` – end block number for historical query
    * `chain_id` – EVM chain ID (default: 1)
    * `limit` – maximum number of events to return

  Output:
    * `events` – list of decoded event maps
    * `count` – total number of events returned
    * `query` – echo of the query parameters
  """

  use Lux.Lens,
    name: "Web3 Contract Events Query",
    description: "Queries historical contract events from the blockchain or cached EventMonitor data",
    schema: %{
      type: :object,
      properties: %{
        subscription_id: %{
          type: :string,
          description: "Existing EventMonitor subscription ID to query events from"
        },
        contract_address: %{
          type: :string,
          description: "Contract address to query events for"
        },
        event_signatures: %{
          type: :array,
          items: %{type: :string},
          description: "Event signatures to filter (e.g. [\"Transfer(address,address,uint256)\"])"
        },
        from_block: %{
          type: :integer,
          description: "Start block number for historical query"
        },
        to_block: %{
          type: :integer,
          description: "End block number for historical query"
        },
        chain_id: %{
          type: :integer,
          description: "EVM chain ID (default: 1)"
        },
        limit: %{
          type: :integer,
          description: "Maximum number of events to return (default: 100)"
        }
      }
    }

  alias Lux.Web3.EventFilter
  alias Lux.Web3.EventMonitor

  def focus(params, _opts) do
    cond do
      # Query from existing subscription
      Map.has_key?(params, :subscription_id) ->
        query_subscription(params)

      # Direct blockchain query
      Map.has_key?(params, :contract_address) ->
        query_blockchain(params)

      true ->
        {:error, "Either :subscription_id or :contract_address is required"}
    end
  end

  defp query_subscription(params) do
    sub_id = params.subscription_id
    limit = Map.get(params, :limit, 100)

    filter = %{
      limit: limit
    }

    filter =
      filter
      |> maybe_put(:min_block, Map.get(params, :from_block))
      |> maybe_put(:max_block, Map.get(params, :to_block))
      |> maybe_put(:event_signatures, Map.get(params, :event_signatures))

    if Process.whereis(EventMonitor) do
      case EventMonitor.query_events(sub_id, filter) do
        {:ok, events} ->
          {:ok,
           %{
             events: format_events(events),
             count: length(events),
             query: %{subscription_id: sub_id, filter: sanitize_filter(filter)}
           }}

        {:error, :not_found} ->
          {:ok,
           %{
             events: [],
             count: 0,
             message: "Subscription '#{sub_id}' not found. Create one via WatchContractPrism first."
           }}
      end
    else
      {:error, :event_monitor_not_running}
    end
  end

  defp query_blockchain(params) do
    address = params.contract_address
    chain_id = Map.get(params, :chain_id, 1)
    from_block = Map.get(params, :from_block, 0)
    to_block = Map.get(params, :to_block, "latest")
    event_sigs = Map.get(params, :event_signatures, [])
    limit = Map.get(params, :limit, 100)

    filter_opts = %{
      contract_address: address,
      event_signatures: event_sigs,
      from_block: from_block,
      to_block: to_block
    }

    case EventFilter.build_filter(filter_opts) do
      {:ok, filter} ->
        case fetch_logs(filter, chain_id) do
          {:ok, logs} ->
            events =
              logs
              |> EventFilter.decode_logs()
              |> Enum.take(limit)

            {:ok,
             %{
               events: format_events(events),
               count: length(events),
               query: %{
                 contract_address: address,
                 chain_id: chain_id,
                 from_block: from_block,
                 to_block: to_block,
                 event_signatures: event_sigs
               }
             }}

          {:error, reason} ->
            {:error, "Failed to fetch logs: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, "Failed to build filter: #{reason}"}
    end
  end

  defp fetch_logs(filter, _chain_id) do
    Ethereumex.HttpClient.eth_get_logs(filter)
  end

  defp format_events(events) do
    Enum.map(events, fn event ->
      %{
        event_signature: event.event_signature,
        contract_address: event.contract_address,
        block_number: event.block_number,
        transaction_hash: event.transaction_hash,
        log_index: event.log_index,
        topics: format_topics(Map.get(event, :topics, [])),
        data: event.data,
        removed: Map.get(event, :removed, false)
      }
    end)
  end

  defp format_topics(topics) when is_list(topics) do
    Enum.map(topics, fn
      %{raw: raw, as_address: addr} -> %{raw: raw, address: addr}
      other -> other
    end)
  end

  defp format_topics(_), do: []

  defp sanitize_filter(filter) do
    Map.drop(filter, [:callback])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
