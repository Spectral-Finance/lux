defmodule Lux.Web3.DataNormalizer do
  @moduledoc """
  Standardizes EVM block, transaction, and event log schemas across EVM chains
  (Ethereum, BSC, Polygon, Arbitrum).
  """

  @valid_chains ["ethereum", "bsc", "polygon", "arbitrum"]

  @doc """
  Normalizes raw block data from JSON-RPC responses across EVM chains.
  """
  def normalize_block(raw_block, chain) when is_map(raw_block) do
    normalized_chain = normalize_chain(chain)

    number = parse_hex_or_int(fetch_field(raw_block, [:number, "number"]))
    hash = normalize_hex_string(fetch_field(raw_block, [:hash, "hash"]))
    parent_hash = normalize_hex_string(fetch_field(raw_block, [:parentHash, "parentHash", :parent_hash, "parent_hash"]))
    timestamp_raw = fetch_field(raw_block, [:timestamp, "timestamp"])
    timestamp_int = parse_hex_or_int(timestamp_raw)
    timestamp_iso = format_iso8601_timestamp(timestamp_int)

    miner = normalize_address(fetch_field(raw_block, [:miner, "miner", :author, "author"]))
    gas_limit = parse_hex_or_int(fetch_field(raw_block, [:gasLimit, "gasLimit", :gas_limit, "gas_limit"]))
    gas_used = parse_hex_or_int(fetch_field(raw_block, [:gasUsed, "gasUsed", :gas_used, "gas_used"]))
    base_fee = parse_hex_or_int(fetch_field(raw_block, [:baseFeePerGas, "baseFeePerGas", :base_fee_per_gas, "base_fee_per_gas"]))
    size = parse_hex_or_int(fetch_field(raw_block, [:size, "size"]))
    extra_data = normalize_hex_string(fetch_field(raw_block, [:extraData, "extraData", :extra_data, "extra_data"]))

    raw_txs = fetch_field(raw_block, [:transactions, "transactions"]) || []

    transactions =
      cond do
        is_list(raw_txs) ->
          Enum.map(raw_txs, fn
            tx when is_map(tx) -> normalize_transaction(tx, normalized_chain)
            tx_hash when is_binary(tx_hash) -> normalize_hex_string(tx_hash)
            other -> other
          end)

        true ->
          []
      end

    %{
      chain: normalized_chain,
      number: number,
      hash: hash,
      parent_hash: parent_hash,
      timestamp: timestamp_int,
      timestamp_iso: timestamp_iso,
      miner: miner,
      gas_limit: gas_limit,
      gas_used: gas_used,
      base_fee_per_gas: base_fee,
      size: size,
      extra_data: extra_data,
      transactions: transactions
    }
  end

  def normalize_block(nil, chain), do: %{chain: normalize_chain(chain), number: nil, hash: nil, transactions: []}

  @doc """
  Normalizes raw transaction data from JSON-RPC responses across EVM chains.
  """
  def normalize_transaction(raw_tx, chain) when is_map(raw_tx) do
    normalized_chain = normalize_chain(chain)

    hash = normalize_hex_string(fetch_field(raw_tx, [:hash, "hash"]))
    block_number = parse_hex_or_int(fetch_field(raw_tx, [:blockNumber, "blockNumber", :block_number, "block_number"]))
    block_hash = normalize_hex_string(fetch_field(raw_tx, [:blockHash, "blockHash", :block_hash, "block_hash"]))
    from = normalize_address(fetch_field(raw_tx, [:from, "from"]))
    to = normalize_address(fetch_field(raw_tx, [:to, "to"]))
    value = parse_hex_or_int(fetch_field(raw_tx, [:value, "value"])) || 0
    gas = parse_hex_or_int(fetch_field(raw_tx, [:gas, "gas", :gasLimit, "gasLimit", :gas_limit, "gas_limit"]))
    gas_price = parse_hex_or_int(fetch_field(raw_tx, [:gasPrice, "gasPrice", :gas_price, "gas_price"]))
    max_fee_per_gas = parse_hex_or_int(fetch_field(raw_tx, [:maxFeePerGas, "maxFeePerGas", :max_fee_per_gas, "max_fee_per_gas"]))
    max_priority_fee_per_gas = parse_hex_or_int(fetch_field(raw_tx, [:maxPriorityFeePerGas, "maxPriorityFeePerGas", :max_priority_fee_per_gas, "max_priority_fee_per_gas"]))
    input = normalize_hex_string(fetch_field(raw_tx, [:input, "input", :data, "data"])) || "0x"
    nonce = parse_hex_or_int(fetch_field(raw_tx, [:nonce, "nonce"]))
    tx_index = parse_hex_or_int(fetch_field(raw_tx, [:transactionIndex, "transactionIndex", :transaction_index, "transaction_index"]))
    type = parse_hex_or_int(fetch_field(raw_tx, [:type, "type"]))

    %{
      chain: normalized_chain,
      hash: hash,
      block_number: block_number,
      block_hash: block_hash,
      from: from,
      to: to,
      value: value,
      gas: gas,
      gas_price: gas_price,
      max_fee_per_gas: max_fee_per_gas,
      max_priority_fee_per_gas: max_priority_fee_per_gas,
      input: input,
      nonce: nonce,
      transaction_index: tx_index,
      type: type
    }
  end

  def normalize_transaction(nil, chain), do: %{chain: normalize_chain(chain), hash: nil, from: nil, to: nil}

  @doc """
  Normalizes raw event log data from JSON-RPC responses across EVM chains.
  """
  def normalize_log(raw_log, chain) when is_map(raw_log) do
    normalized_chain = normalize_chain(chain)

    address = normalize_address(fetch_field(raw_log, [:address, "address"]))
    topics_raw = fetch_field(raw_log, [:topics, "topics"]) || []
    topics = Enum.map(topics_raw, &normalize_hex_string/1)
    data = normalize_hex_string(fetch_field(raw_log, [:data, "data"])) || "0x"
    block_number = parse_hex_or_int(fetch_field(raw_log, [:blockNumber, "blockNumber", :block_number, "block_number"]))
    block_hash = normalize_hex_string(fetch_field(raw_log, [:blockHash, "blockHash", :block_hash, "block_hash"]))
    tx_hash = normalize_hex_string(fetch_field(raw_log, [:transactionHash, "transactionHash", :transaction_hash, "transaction_hash"]))
    tx_index = parse_hex_or_int(fetch_field(raw_log, [:transactionIndex, "transactionIndex", :transaction_index, "transaction_index"]))
    log_index = parse_hex_or_int(fetch_field(raw_log, [:logIndex, "logIndex", :log_index, "log_index"]))
    removed = fetch_field(raw_log, [:removed, "removed"]) == true

    %{
      chain: normalized_chain,
      address: address,
      topics: topics,
      data: data,
      block_number: block_number,
      block_hash: block_hash,
      transaction_hash: tx_hash,
      transaction_index: tx_index,
      log_index: log_index,
      removed: removed
    }
  end

  def normalize_log(nil, chain), do: %{chain: normalize_chain(chain), address: nil, topics: []}

  @doc """
  Normalizes chain identifier string to standard form ("ethereum", "bsc", "polygon", "arbitrum").
  """
  def normalize_chain(chain) when is_atom(chain), do: normalize_chain(Atom.to_string(chain))
  def normalize_chain(chain) when is_binary(chain) do
    case String.downcase(chain) do
      "binance_smart_chain" -> "bsc"
      "eth" -> "ethereum"
      c when c in @valid_chains -> c
      c -> c
    end
  end
  def normalize_chain(_), do: "ethereum"

  @doc """
  Parses a hex string (e.g. "0x1a") or integer into an integer.
  """
  def parse_hex_or_int(nil), do: nil
  def parse_hex_or_int(val) when is_integer(val), do: val

  def parse_hex_or_int(val) when is_binary(val) do
    case String.trim(val) do
      "0x" <> hex ->
        case Integer.parse(hex, 16) do
          {int, _} -> int
          :error -> nil
        end

      str ->
        case Integer.parse(str) do
          {int, _} -> int
          :error -> nil
        end
    end
  end

  def parse_hex_or_int(_), do: nil

  @doc """
  Normalizes hex strings to lower-case with "0x" prefix.
  """
  def normalize_hex_string(nil), do: nil

  def normalize_hex_string(val) when is_binary(val) do
    val = String.trim(val)

    cond do
      String.starts_with?(val, "0x") or String.starts_with?(val, "0X") ->
        "0x" <> String.downcase(Binary.part(val, 2, byte_size(val) - 2))

      val == "" ->
        nil

      true ->
        "0x" <> String.downcase(val)
    end
  end

  def normalize_hex_string(_), do: nil

  @doc """
  Normalizes EVM address to lowercase hex string with 0x prefix.
  """
  def normalize_address(nil), do: nil
  def normalize_address(val) when is_binary(val), do: normalize_hex_string(val)
  def normalize_address(_), do: nil

  defp fetch_field(map, keys) when is_map(map) do
    Enum.find_value(keys, fn key -> Map.get(map, key) end)
  end
  defp fetch_field(_, _), do: nil

  defp format_iso8601_timestamp(nil), do: nil
  defp format_iso8601_timestamp(seconds) when is_integer(seconds) do
    case DateTime.from_unix(seconds) do
      {:ok, datetime} -> DateTime.to_iso8601(datetime)
      _ -> nil
    end
  end
end
