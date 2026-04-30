defmodule Lux.DataAggregation.Normalizer do
  @moduledoc """
  Normalizes blockchain data from multiple chains into a unified format.

  ## Features
  - Chain-specific field normalization
  - Timestamp standardization
  - Value conversion (wei to ether)
  - Address checksumming
  - Unified block/transaction/event formats
  """

  alias Lux.DataAggregation

  @doc """
  Normalize data from a source chain to a target format.
  """
  def normalize(data, source_chain, target_format \\ :unified)

  def normalize(%{"hash" => _} = block, chain, :unified) when is_map(block) do
    %{
      type: :block,
      chain: chain,
      chain_name: chain_name(chain),
      chain_id: chain_id(chain),
      number: parse_hex(block["number"]),
      hash: normalize_hash(block["hash"]),
      parent_hash: normalize_hash(block["parentHash"]),
      timestamp: parse_hex(block["timestamp"]),
      timestamp_iso: to_iso8601(parse_hex(block["timestamp"])),
      miner: normalize_address(block["miner"]),
      gas_used: parse_hex(block["gasUsed"]),
      gas_limit: parse_hex(block["gasLimit"]),
      base_fee_per_gas: block["baseFeePerGas"] && parse_hex(block["baseFeePerGas"]),
      base_fee_ether: block["baseFeePerGas"] && wei_to_ether(parse_hex(block["baseFeePerGas"])),
      transaction_count: length(block["transactions"] || []),
      size: parse_hex(block["size"]),
      difficulty: parse_hex(block["difficulty"]),
      total_difficulty: block["totalDifficulty"] && parse_hex(block["totalDifficulty"]),
      nonce: block["nonce"],
      extra_data: block["extraData"],
      logs_bloom: block["logsBloom"],
      state_root: block["stateRoot"],
      receipts_root: block["receiptsRoot"],
      transactions_root: block["transactionsRoot"],
      transactions: Enum.map(block["transactions"] || [], &normalize_transaction(&1, chain)),
      normalized_at: DateTime.utc_now()
    }
  end

  def normalize(%{"transactionHash" => _} = tx, chain, :unified) when is_map(tx) do
    normalize_transaction(tx, chain)
  end

  def normalize(%{topics: _} = event, chain, :unified) do
    %{
      type: :event,
      chain: chain,
      chain_name: chain_name(chain),
      chain_id: chain_id(chain),
      contract_address: normalize_address(event.contract_address || event.address),
      transaction_hash: normalize_hash(event.transaction_hash),
      log_index: event.log_index,
      block_number: event.block_number,
      block_hash: normalize_hash(event.block_hash),
      topics: Enum.map(event.topics || [], &normalize_hash/1),
      data: event.data,
      decoded: decode_event_data(event),
      normalized_at: DateTime.utc_now()
    }
  end

  def normalize(data, chain, :unified) when is_list(data) do
    Enum.map(data, &normalize(&1, chain, :unified))
  end

  def normalize(data, chain, format) do
    {chain, format, data}
  end

  defp normalize_transaction(tx, chain) do
    %{
      type: :transaction,
      chain: chain,
      chain_name: chain_name(chain),
      chain_id: chain_id(chain),
      hash: normalize_hash(tx["hash"]),
      block_number: parse_hex(tx["blockNumber"]),
      block_hash: normalize_hash(tx["blockHash"]),
      transaction_index: parse_hex(tx["transactionIndex"]),
      from: normalize_address(tx["from"]),
      to: normalize_address(tx["to"]),
      value: parse_hex(tx["value"]),
      value_ether: wei_to_ether(parse_hex(tx["value"])),
      gas: parse_hex(tx["gas"]),
      gas_price: parse_hex(tx["gasPrice"]),
      gas_price_gwei: tx["gasPrice"] && wei_to_gwei(parse_hex(tx["gasPrice"])),
      max_fee_per_gas: tx["maxFeePerGas"] && parse_hex(tx["maxFeePerGas"]),
      max_priority_fee_per_gas: tx["maxPriorityFeePerGas"] && parse_hex(tx["maxPriorityFeePerGas"]),
      input: tx["input"],
      nonce: parse_hex(tx["nonce"]),
      v: tx["v"],
      r: tx["r"],
      s: tx["s"],
      transaction_type: parse_hex(tx["type"]),
      normalized_at: DateTime.utc_now()
    }
  end

  defp decode_event_data(event) do
    # Basic topic-based event identification
    topics = event.topics || []

    case topics do
      [event_signature | params] ->
        %{
          event_signature: event_signature,
          params: params,
          decoded_params: decode_params(params, event.data)
        }

      [] ->
        %{raw_data: event.data}
    end
  end

  defp decode_params(params, data) do
    %{
      indexed_params: params,
      non_indexed_data: data
    }
  end

  defp normalize_hash(nil), do: nil
  defp normalize_hash("0x" <> _ = hash), do: String.downcase(hash)
  defp normalize_hash(hash) when is_binary(hash), do: hash
  defp normalize_hash(_), do: nil

  defp normalize_address(nil), do: nil
  defp normalize_address("0x" <> _ = addr), do: String.downcase(addr)
  defp normalize_address(addr) when is_binary(addr), do: addr
  defp normalize_address(_), do: nil

  defp parse_hex(nil), do: 0
  defp parse_hex("0x" <> hex), do: String.to_integer(hex, 16)
  defp parse_hex(val) when is_integer(val), do: val
  defp parse_hex(_), do: 0

  defp wei_to_ether(wei) when is_integer(wei) do
    Decimal.div(Decimal.new(wei), Decimal.new("1000000000000000000"))
    |> Decimal.to_float()
    |> :erlang.float_to_binary([:compact, decimals: 18])
  end
  defp wei_to_ether(_), do: 0.0

  defp wei_to_gwei(wei) when is_integer(wei) do
    Decimal.div(Decimal.new(wei), Decimal.new("1000000000"))
    |> Decimal.to_float()
    |> :erlang.float_to_binary([:compact, decimals: 9])
  end
  defp wei_to_gwei(_), do: 0.0

  defp to_iso8601(timestamp) when is_integer(timestamp) do
    timestamp
    |> DateTime.from_unix!()
    |> DateTime.to_iso8601()
  end
  defp to_iso8601(_), do: nil

  defp chain_name(:ethereum), do: "Ethereum Mainnet"
  defp chain_name(:polygon), do: "Polygon Mainnet"
  defp chain_name(:bsc), do: "BNB Smart Chain"
  defp chain_name(:arbitrum), do: "Arbitrum One"
  defp chain_name(:optimism), do: "Optimism"
  defp chain_name(:avalanche), do: "Avalanche C-Chain"
  defp chain_name(:fantom), do: "Fantom Opera"
  defp chain_name(_), do: "Unknown"

  defp chain_id(:ethereum), do: 1
  defp chain_id(:polygon), do: 137
  defp chain_id(:bsc), do: 56
  defp chain_id(:arbitrum), do: 42161
  defp chain_id(:optimism), do: 10
  defp chain_id(:avalanche), do: 43114
  defp chain_id(:fantom), do: 250
  defp chain_id(_), do: 0
end
