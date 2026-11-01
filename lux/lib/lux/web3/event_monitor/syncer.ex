defmodule Lux.Web3.EventMonitor.Syncer do
  @moduledoc """
  Historical event synchronization engine with chunked batch scanning (#75).

  Pulls past logs from EVM nodes in safe block chunks (to avoid RPC limit rejection),
  normalizes them, runs pattern filtering, and loads them into the event store.
  """

  alias Lux.Web3.EventMonitor.Schemas.{MonitoredEvent, Subscription}
  alias Lux.Web3.EventMonitor.{Decoder, FilterEngine}

  @default_chunk_size 2_000

  @doc """
  Synchronizes historical logs for a given subscription between from_block and to_block.
  """
  @spec sync_historical(Subscription.t(), non_neg_integer(), non_neg_integer(), keyword()) ::
          {:ok, %{blocks_scanned: non_neg_integer(), events_found: non_neg_integer(), chunks: non_neg_integer()}}
          | {:error, term()}
  def sync_historical(%Subscription{} = sub, from_block, to_block, opts \\ []) do
    chunk_size = Keyword.get(opts, :chunk_size, @default_chunk_size)
    rpc_client = Keyword.get(opts, :rpc_client)
    event_store = Keyword.get(opts, :event_store)

    if from_block > to_block do
      {:error, :invalid_block_range}
    else
      chunks = generate_chunks(from_block, to_block, chunk_size)

      result =
        Enum.reduce_while(chunks, {:ok, 0, 0}, fn {start_blk, end_blk}, {:ok, total_scanned, total_events} ->
          case fetch_and_process_chunk(sub, start_blk, end_blk, rpc_client, event_store) do
            {:ok, events_in_chunk} ->
              scanned_in_chunk = end_blk - start_blk + 1
              {:cont, {:ok, total_scanned + scanned_in_chunk, total_events + events_in_chunk}}

            {:error, reason} ->
              {:halt, {:error, reason}}
          end
        end)

      case result do
        {:ok, scanned, found} ->
          {:ok, %{blocks_scanned: scanned, events_found: found, chunks: length(chunks)}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Splits a block range into discrete chunk intervals of max_chunk size.
  """
  @spec generate_chunks(non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          [{non_neg_integer(), non_neg_integer()}]
  def generate_chunks(from_block, to_block, chunk_size) when from_block <= to_block do
    Stream.iterate(from_block, &(&1 + chunk_size))
    |> Stream.take_while(&(&1 <= to_block))
    |> Enum.map(fn start_blk ->
      end_blk = min(start_blk + chunk_size - 1, to_block)
      {start_blk, end_blk}
    end)
  end

  defp fetch_and_process_chunk(sub, start_blk, end_blk, rpc_client, event_store) do
    # Fetch logs from RPC client if provided
    raw_logs =
      cond do
        is_function(rpc_client, 3) ->
          rpc_client.(sub, start_blk, end_blk)

        is_list(rpc_client) ->
          # Mock logs list passed directly for testing
          rpc_client

        true ->
          []
      end

    events =
      raw_logs
      |> Enum.map(&normalize_raw_log(&1, sub))
      |> Enum.reject(&is_nil/1)
      |> Enum.filter(&FilterEngine.matches?(&1, sub))

    # Store if store provided
    if event_store do
      Enum.each(events, fn ev ->
        apply(event_store, :store_event, [ev])
      end)
    end

    {:ok, length(events)}
  end

  defp normalize_raw_log(raw, sub) when is_map(raw) do
    topics = (raw[:topics] || raw["topics"] || []) |> Enum.map(&String.downcase(to_string(&1)))
    data = raw[:data] || raw["data"]

    decoded =
      case Decoder.decode(topics, data) do
        {:ok, p} -> p
        _ -> %{}
      end

    tx_hash = String.downcase(to_string(raw[:transactionHash] || raw["transactionHash"] || "0x0"))
    log_idx = parse_int(raw[:logIndex] || raw["logIndex"]) || 0
    blk_num = parse_int(raw[:blockNumber] || raw["blockNumber"]) || 0
    blk_hash = raw[:blockHash] || raw["blockHash"]
    contract = String.downcase(to_string(raw[:address] || raw["address"] || sub.contract_address))

    evt_id = "evt_#{sub.chain_id}_#{String.trim_leading(tx_hash, "0x")}_#{log_idx}"

    %MonitoredEvent{
      id: evt_id,
      subscription_id: sub.id,
      chain_id: sub.chain_id,
      chain: sub.chain,
      contract_address: contract,
      event_name: decoded[:_event_type] || sub.event_name,
      event_signature: decoded[:_event_signature] || sub.event_signature,
      block_number: blk_num,
      block_hash: blk_hash,
      tx_hash: tx_hash,
      log_index: log_idx,
      topics: topics,
      data: data,
      decoded_params: decoded,
      timestamp: System.system_time(:second)
    }
  end

  defp parse_int(nil), do: nil
  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(val) when is_binary(val) do
    clean = String.trim_leading(val, "0x")
    case Integer.parse(clean, 16) do
      {num, _} -> num
      _ ->
        case Integer.parse(val, 10) do
          {num, _} -> num
          _ -> nil
        end
    end
  end
  defp parse_int(_), do: nil
end
