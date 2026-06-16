defmodule Lux.Web3.MultiChain.Aggregator do
  @moduledoc """
  Multi-chain data aggregation helpers for EVM-compatible networks.

  This module normalizes block, transaction, and event records from many chains
  into a common queryable snapshot. It also builds JSON-RPC polling plans for
  latest blocks, transaction receipts, and contract logs so callers can connect
  live RPC clients without coupling storage or networking to this core module.
  """

  @major_evm_chains %{
    "ethereum" => %{chain_id: 1, avg_block_seconds: 12},
    "base" => %{chain_id: 8453, avg_block_seconds: 2},
    "arbitrum" => %{chain_id: 42161, avg_block_seconds: 0.26},
    "optimism" => %{chain_id: 10, avg_block_seconds: 2},
    "polygon" => %{chain_id: 137, avg_block_seconds: 2},
    "bsc" => %{chain_id: 56, avg_block_seconds: 3}
  }

  @spec supported_chains() :: map()
  def supported_chains, do: @major_evm_chains

  @spec normalize_chain(map()) :: {:ok, map()} | {:error, String.t()}
  def normalize_chain(attrs) when is_map(attrs) do
    with {:ok, name} <- required_string(attrs, :name, [:chain]),
         {:ok, chain_id} <-
           integer_value(
             attrs,
             :chain_id,
             Map.get(@major_evm_chains[String.downcase(name)] || %{}, :chain_id)
           ) do
      {:ok,
       %{
         name: String.downcase(name),
         chain_id: chain_id,
         rpc_url: blank_to_nil(get_value(attrs, :rpc_url)),
         avg_block_seconds:
           number(
             attrs,
             :avg_block_seconds,
             Map.get(@major_evm_chains[String.downcase(name)] || %{}, :avg_block_seconds, 12)
           )
       }}
    end
  end

  def normalize_chain(_), do: {:error, "chain must be a map"}

  @spec normalize_block(map()) :: {:ok, map()} | {:error, String.t()}
  def normalize_block(attrs) when is_map(attrs) do
    with {:ok, chain} <- required_string(attrs, :chain, []),
         {:ok, number} <- integer_value(attrs, :number, nil),
         {:ok, hash} <- required_string(attrs, :hash, []) do
      {:ok,
       %{
         chain: String.downcase(chain),
         number: number,
         hash: String.downcase(hash),
         timestamp: normalize_timestamp(get_value(attrs, :timestamp)),
         tx_count: integer_value!(attrs, :tx_count, 0)
       }}
    end
  end

  def normalize_block(_), do: {:error, "block must be a map"}

  @spec normalize_transaction(map()) :: {:ok, map()} | {:error, String.t()}
  def normalize_transaction(attrs) when is_map(attrs) do
    with {:ok, chain} <- required_string(attrs, :chain, []),
         {:ok, hash} <- required_string(attrs, :hash, []) do
      {:ok,
       %{
         chain: String.downcase(chain),
         hash: String.downcase(hash),
         block_number: integer_value!(attrs, :block_number, 0),
         from: normalize_optional_address(get_value(attrs, :from)),
         to: normalize_optional_address(get_value(attrs, :to)),
         value_wei: to_string(get_value(attrs, :value_wei, "0")),
         gas_used: integer_value!(attrs, :gas_used, 0),
         status: get_value(attrs, :status, "unknown")
       }}
    end
  end

  def normalize_transaction(_), do: {:error, "transaction must be a map"}

  @spec normalize_event(map()) :: {:ok, map()} | {:error, String.t()}
  def normalize_event(attrs) when is_map(attrs) do
    with {:ok, chain} <- required_string(attrs, :chain, []),
         {:ok, address} <- required_string(attrs, :address, []),
         {:ok, topic0} <- required_string(attrs, :topic0, [:event_signature]) do
      {:ok,
       %{
         chain: String.downcase(chain),
         address: normalize_address(address),
         topic0: String.downcase(topic0),
         event_name: blank_to_nil(get_value(attrs, :event_name)),
         block_number: integer_value!(attrs, :block_number, 0),
         tx_hash: String.downcase(to_string(get_value(attrs, :tx_hash, ""))),
         log_index: integer_value!(attrs, :log_index, 0),
         args: get_value(attrs, :args, %{})
       }}
    end
  end

  def normalize_event(_), do: {:error, "event must be a map"}

  @spec snapshot(map()) :: {:ok, map()} | {:error, String.t()}
  def snapshot(attrs) when is_map(attrs) do
    with {:ok, chains} <- normalize_many(get_value(attrs, :chains, []), &normalize_chain/1),
         {:ok, blocks} <- normalize_many(get_value(attrs, :blocks, []), &normalize_block/1),
         {:ok, transactions} <-
           normalize_many(get_value(attrs, :transactions, []), &normalize_transaction/1),
         {:ok, events} <- normalize_many(get_value(attrs, :events, []), &normalize_event/1) do
      {:ok,
       %{
         chains: chains,
         latest_blocks: latest_blocks(blocks),
         blocks: blocks,
         transactions: transactions,
         events: events,
         event_counts: count_by(events, :event_name),
         tx_counts_by_chain: count_by(transactions, :chain),
         generated_at: DateTime.utc_now()
       }}
    end
  end

  def snapshot(_), do: {:error, "snapshot input must be a map"}

  @spec query(map(), keyword()) :: map()
  def query(snapshot, opts \\ []) when is_map(snapshot) do
    chain = opts[:chain]
    address = opts[:address] && normalize_address(opts[:address])
    event_name = opts[:event_name]
    min_block = opts[:min_block] || 0

    filtered_events =
      snapshot.events
      |> Enum.filter(fn event ->
        (is_nil(chain) or event.chain == String.downcase(to_string(chain))) and
          (is_nil(address) or event.address == address) and
          (is_nil(event_name) or event.event_name == event_name) and
          event.block_number >= min_block
      end)

    %{
      events: filtered_events,
      count: length(filtered_events),
      event_counts: count_by(filtered_events, :event_name)
    }
  end

  @spec rpc_plan([map()], keyword()) :: [map()]
  def rpc_plan(chains, opts \\ []) when is_list(chains) do
    latest? = Keyword.get(opts, :latest_block, true)
    event_filters = Keyword.get(opts, :event_filters, [])

    chains
    |> Enum.flat_map(fn chain ->
      name = get_value(chain, :name, get_value(chain, :chain))
      rpc_url = get_value(chain, :rpc_url)

      latest_requests =
        if latest? do
          [
            %{
              chain: name,
              rpc_url: rpc_url,
              method: "eth_blockNumber",
              params: [],
              purpose: "latest_block"
            }
          ]
        else
          []
        end

      log_requests =
        Enum.map(event_filters, fn filter ->
          %{
            chain: name,
            rpc_url: rpc_url,
            method: "eth_getLogs",
            params: [
              %{
                address: get_value(filter, :address),
                fromBlock: get_value(filter, :from_block, "latest"),
                toBlock: get_value(filter, :to_block, "latest"),
                topics: get_value(filter, :topics, [])
              }
            ],
            purpose: "contract_event_sync"
          }
        end)

      latest_requests ++ log_requests
    end)
  end

  @spec retention_filter(map(), non_neg_integer()) :: map()
  def retention_filter(snapshot, min_block) when is_map(snapshot) do
    %{
      snapshot
      | blocks: Enum.filter(snapshot.blocks, &(&1.number >= min_block)),
        transactions: Enum.filter(snapshot.transactions, &(&1.block_number >= min_block)),
        events: Enum.filter(snapshot.events, &(&1.block_number >= min_block))
    }
  end

  @spec stream_payload(map()) :: map()
  def stream_payload(snapshot) do
    %{
      type: "multi_chain_snapshot",
      chain_count: length(snapshot.chains),
      latest_blocks: snapshot.latest_blocks,
      tx_count: length(snapshot.transactions),
      event_count: length(snapshot.events),
      event_counts: snapshot.event_counts
    }
  end

  defp normalize_many(items, fun) when is_list(items) do
    items
    |> Enum.reduce_while({:ok, []}, fn item, {:ok, acc} ->
      case fun.(item) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      error -> error
    end
  end

  defp normalize_many(_, _), do: {:error, "items must be a list"}

  defp latest_blocks(blocks) do
    blocks
    |> Enum.group_by(& &1.chain)
    |> Map.new(fn {chain, items} -> {chain, Enum.max_by(items, & &1.number)} end)
  end

  defp count_by(items, key) do
    items
    |> Enum.map(&Map.get(&1, key))
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
  end

  defp required_string(attrs, key, aliases) do
    [key | aliases]
    |> Enum.map(&get_value(attrs, &1))
    |> Enum.find(&present?/1)
    |> case do
      value when is_binary(value) -> {:ok, value}
      value when not is_nil(value) -> {:ok, to_string(value)}
      _ -> {:error, "Missing required #{key}"}
    end
  end

  defp integer_value(attrs, key, default) do
    case get_value(attrs, key, default) do
      value when is_integer(value) ->
        {:ok, value}

      value when is_binary(value) ->
        case Integer.parse(value) do
          {parsed, _} -> {:ok, parsed}
          :error -> {:error, "#{key} must be an integer"}
        end

      nil ->
        {:error, "Missing required #{key}"}

      _ ->
        {:error, "#{key} must be an integer"}
    end
  end

  defp integer_value!(attrs, key, default) do
    case integer_value(attrs, key, default) do
      {:ok, value} -> value
      {:error, _} -> default
    end
  end

  defp number(attrs, key, default) do
    case get_value(attrs, key, default) do
      value when is_integer(value) or is_float(value) ->
        value

      value when is_binary(value) ->
        case Float.parse(value) do
          {parsed, _} -> parsed
          :error -> default
        end

      _ ->
        default
    end
  end

  defp normalize_timestamp(nil), do: nil
  defp normalize_timestamp(%DateTime{} = timestamp), do: timestamp

  defp normalize_timestamp(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      _ -> nil
    end
  end

  defp normalize_timestamp(_), do: nil

  defp normalize_optional_address(nil), do: nil
  defp normalize_optional_address(value), do: normalize_address(value)

  defp normalize_address(value) do
    value
    |> to_string()
    |> String.downcase()
  end

  defp get_value(attrs, key, default \\ nil),
    do: Map.get(attrs, key, Map.get(attrs, to_string(key), default))

  defp blank_to_nil(value) when is_binary(value),
    do: if(String.trim(value) == "", do: nil, else: String.trim(value))

  defp blank_to_nil(value), do: value
  defp present?(value), do: not is_nil(blank_to_nil(value))
end
