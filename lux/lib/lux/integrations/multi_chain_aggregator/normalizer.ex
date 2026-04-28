defmodule Lux.Integrations.MultiChainAggregator.Normalizer do
  @moduledoc """
  Data normalization across chains. Converts chain-specific formats
  into a unified data structure for consistent querying.
  """

  @chain_names %{
    1 => "ethereum", 56 => "bsc", 137 => "polygon",
    42161 => "arbitrum", 10 => "optimism", 8453 => "base",
    43114 => "avalanche", 250 => "fantom"
  }

  def normalize_block(nil, _chain), do: nil
  def normalize_block(block, chain) when is_map(block) do
    %{
      chain: chain,
      chain_name: @chain_names[block["chainId"]] || Atom.to_string(chain),
      number: parse_hex(block["number"]),
      hash: block["hash"],
      parent_hash: block["parentHash"],
      timestamp: parse_hex(block["timestamp"]),
      gas_used: parse_hex(block["gasUsed"]),
      gas_limit: parse_hex(block["gasLimit"]),
      transaction_count: length(block["transactions"] || []),
      miner: block["miner"] || block["author"]
    }
  end

  def normalize_transaction(nil, _chain), do: nil
  def normalize_transaction(tx, chain) when is_map(tx) do
    %{
      chain: chain,
      hash: tx["hash"],
      block_number: parse_hex(tx["blockNumber"]),
      from: tx["from"],
      to: tx["to"],
      value_wei: parse_hex(tx["value"]),
      value_eth: parse_wei_to_eth(tx["value"]),
      gas_price: parse_hex(tx["gasPrice"]),
      nonce: parse_hex(tx["nonce"]),
      input: tx["input"]
    }
  end

  def normalize_receipt(nil, _chain), do: nil
  def normalize_receipt(receipt, chain) when is_map(receipt) do
    %{
      chain: chain,
      tx_hash: receipt["transactionHash"],
      block_number: parse_hex(receipt["blockNumber"]),
      gas_used: parse_hex(receipt["gasUsed"]),
      status: parse_hex(receipt["status"]),
      logs: Enum.map(receipt["logs"] || [], &normalize_log_entry(&1, chain)),
      contract_address: receipt["contractAddress"]
    }
  end

  def normalize_logs(nil, _chain), do: []
  def normalize_logs(logs, chain) when is_list(logs) do
    Enum.map(logs, &normalize_log_entry(&1, chain))
  end

  def normalize_log_entry(log, chain) do
    %{
      chain: chain,
      address: log["address"],
      topics: log["topics"],
      data: log["data"],
      block_number: parse_hex(log["blockNumber"]),
      tx_hash: log["transactionHash"],
      log_index: parse_hex(log["logIndex"]),
      removed: log["removed"] || false
    }
  end

  defp parse_hex("0x" <> hex), do: String.to_integer(hex, 16)
  defp parse_hex(val) when is_binary(val), do: String.to_integer(val, 16)
  defp parse_hex(val) when is_integer(val), do: val
  defp parse_hex(_), do: 0

  defp parse_wei_to_eth("0x" <> hex) do
    wei = String.to_integer(hex, 16)
    Float.round(wei / 1.0e18, 18)
  end
  defp parse_wei_to_eth(_), do: 0.0
end