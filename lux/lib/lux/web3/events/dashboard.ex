defmodule Lux.Web3.Events.Dashboard do
  @moduledoc """
  Dashboard query lens for event monitoring visualization.

  Provides high-level aggregation queries suitable for dashboard
  displays: event counts, recent activity, contract summaries,
  and trend data.
  """

  alias Lux.Web3.Events.Store

  @doc """
  Routes dashboard queries to the appropriate handler.
  Used by the EventMonitoring lens.
  """
  @spec query(atom(), term()) :: {:ok, any()} | {:error, term()}
  def query(:snapshot, limit \ 20) do
    with {:ok, stats} <- Store.stats(),
         {:ok, recent} <- Store.get_recent_events(limit) do
      {:ok, %{
        total_events: stats.total,
        total_contracts: stats.contracts,
        contracts: stats.by_contract,
        recent_events: recent
      }}
    else
      {:error, error} -> {:error, error}
    end
  end

  def query(:recent, limit) do
    Store.get_recent_events(limit)
  end

  def query(:contract_summary) do
    Store.stats()
  end

  def query(:contract_events, opts) do
    contract = opts[:contract]
    limit = opts[:limit] || 100

    events =
      case {opts[:from_block], opts[:to_block]} do
        {from, to} when is_number(from) and is_number(to) ->
          Store.get_events_in_block_range(contract, from, to)

        _ ->
          Store.get_events_for_contract(contract)
          |> Enum.take(limit)
      end

    {:ok, events}
  end

  def query(:event_types, contract) do
    events = Store.get_events_for_contract(contract)

    dist =
      events
      |> Enum.group_by(& &1.topic0)
      |> Enum.map(fn {topic, evts} ->
        %{
          topic0: topic,
          count: length(evts),
          first_seen: Enum.min_by(evts, & &1.timestamp).timestamp,
          last_seen: Enum.max_by(evts, & &1.timestamp).timestamp
        }
      end)
      |> Enum.sort_by(& &1.count, :desc)

    {:ok, dist}
  end

  def query(:event_frequency, opts) do
    contract = opts[:contract]
    from = opts[:from_block] || 0
    to = opts[:to_block] || 0
    bucket = opts[:bucket_size] || 100

    events = Store.get_events_for_contract(contract)

    buckets =
      events
      |> Enum.filter(fn e -> e.block_number >= from and e.block_number <= to end)
      |> Enum.group_by(fn e -> div(e.block_number - from, bucket) end, & &1.block_number)
      |> Enum.map(fn {bucket_idx, blocks} ->
        %{
          bucket: bucket_idx,
          block_start: from + bucket_idx * bucket,
          event_count: length(blocks),
          unique_transactions: Enum.uniq(blocks) |> length()
        }
      end)
      |> Enum.sort_by(& &1.bucket)

    {:ok, buckets}
  end

  # Legacy convenience functions

  @doc """
  Gets a summary of all monitored contracts and their event counts.
  """
  @spec contract_summary() :: {:ok, [map()]} | {:error, term()}
  def contract_summary() do
    case Store.stats() do
      {:ok, %{by_contract: by_contract, total: total, contracts: count}} ->
        {:ok, [
          total_events: total,
          total_contracts: count,
          contracts:
            by_contract
            |> Enum.sort_by(fn {_k, v} -> v end, :desc)
            |> Enum.map(fn {address, events} ->
              %{
                contract_address: address,
                event_count: events,
                percentage: if(total > 0, do: round(events / total * 100), else: 0)
              }
            end)
        ]}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets recent events for dashboard display.
  """
  @spec recent_events(non_neg_integer()) :: {:ok, [map()]} | {:error, term()}
  def recent_events(limit \ 20) do
    case Store.get_recent_events(limit) do
      {:ok, events} ->
        {:ok,
         Enum.map(events, fn e ->
           %{
             block_number: e.block_number,
             transaction_hash: e.transaction_hash,
             contract_address: e.contract_address,
             topic0: e.topic0,
             timestamp: e.timestamp,
             decoded_params: e.decoded_params,
             chain_id: e.chain_id
           }
         end)}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets events for a specific contract with optional block range filter.
  """
  @spec contract_events(String.t(), opts :: map()) :: {:ok, [map()]} | {:error, term()}
  def contract_events(contract_address, opts \ %{}) do
    limit = Map.get(opts, :limit, 100)
    from_block = Map.get(opts, :from_block)
    to_block = Map.get(opts, :to_block)

    events =
      cond do
        from_block and to_block ->
          Store.get_events_in_block_range(contract_address, from_block, to_block)

        true ->
          Store.get_events_for_contract(contract_address)
          |> Enum.take(limit)
      end

    {:ok, events}
  end

  @doc """
  Gets event frequency data for charting (events per block range).
  """
  @spec event_frequency(String.t(), non_neg_integer(), non_neg_integer()) ::
          {:ok, [map()]} | {:error, term()}
  def event_frequency(contract_address, from_block, to_block, bucket_size \ 100) do
    events = Store.get_events_for_contract(contract_address)

    buckets =
      events
      |> Enum.group_by(fn e ->
        div(e.block_number - from_block, bucket_size)
      end, fn e ->
        e.block_number
      end)
      |> Enum.map(fn {bucket, blocks} ->
        %{
          bucket: bucket,
          block_start: from_block + bucket * bucket_size,
          event_count: length(blocks),
          unique_transactions: Enum.uniq(blocks) |> length()
        }
      end)
      |> Enum.sort_by(& &1.bucket)

    {:ok, buckets}
  end

  @doc """
  Gets event type distribution for a contract.
  """
  @spec event_type_distribution(String.t()) :: {:ok, [map()]} | {:error, term()}
  def event_type_distribution(contract_address) do
    events = Store.get_events_for_contract(contract_address)

    distribution =
      events
      |> Enum.group_by(& &1.topic0)
      |> Enum.map(fn {topic, evts} ->
        %{
          topic0: topic,
          count: length(evts),
          first_seen: Enum.min_by(evts, & &1.timestamp).timestamp,
          last_seen: Enum.max_by(evts, & &1.timestamp).timestamp
        }
      end)
      |> Enum.sort_by(& &1.count, :desc)

    {:ok, distribution}
  end

  @doc """
  Full dashboard snapshot combining all metrics.
  """
  @spec snapshot() :: {:ok, map()} | {:error, term()}
  def snapshot() do
    with {:ok, summary} <- contract_summary(),
         {:ok, recent} <- recent_events(10) do
      {:ok, %{
        summary: summary,
        recent_events: recent,
        uptime: :erlang.statistics(:wall_clock)
      }}
    else
      {:error, error} -> {:error, error}
    end
  end
end
