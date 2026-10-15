defmodule Lux.Web3.Aggregator.Normalizer do
  @moduledoc """
  Cross-chain data normalizer converting raw EVM JSON-RPC blocks, transactions,
  and smart contract event logs into canonical structures across Ethereum, BSC,
  Polygon, Arbitrum, Optimism, Base, and Avalanche.
  """

  @transfer_topic "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
  @approval_topic "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"
  @swap_topic "0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822"

  defmodule NormalizedBlock do
    @moduledoc """
    Canonical representation of an EVM block across chains.
    """

    @type t :: %__MODULE__{
            chain: atom(),
            chain_id: pos_integer(),
            block_number: non_neg_integer(),
            block_hash: String.t(),
            parent_hash: String.t() | nil,
            timestamp: non_neg_integer(),
            gas_used: non_neg_integer(),
            gas_limit: non_neg_integer(),
            base_fee_per_gas: non_neg_integer() | nil,
            tx_count: non_neg_integer(),
            transactions: [map()]
          }

    defstruct chain: :ethereum,
              chain_id: 1,
              block_number: 0,
              block_hash: nil,
              parent_hash: nil,
              timestamp: 0,
              gas_used: 0,
              gas_limit: 0,
              base_fee_per_gas: nil,
              tx_count: 0,
              transactions: []
  end

  defmodule NormalizedTransaction do
    @moduledoc """
    Canonical representation of an EVM transaction across chains.
    """

    @type t :: %__MODULE__{
            chain: atom(),
            chain_id: pos_integer(),
            tx_hash: String.t(),
            block_number: non_neg_integer(),
            from: String.t() | nil,
            to: String.t() | nil,
            value_wei: non_neg_integer(),
            gas: non_neg_integer(),
            gas_price_wei: non_neg_integer(),
            nonce: non_neg_integer(),
            input: String.t(),
            timestamp: non_neg_integer()
          }

    defstruct chain: :ethereum,
              chain_id: 1,
              tx_hash: nil,
              block_number: 0,
              from: nil,
              to: nil,
              value_wei: 0,
              gas: 0,
              gas_price_wei: 0,
              nonce: 0,
              input: "0x",
              timestamp: 0
  end

  defmodule NormalizedEvent do
    @moduledoc """
    Canonical representation of a smart contract event log across chains.
    """

    @type t :: %__MODULE__{
            id: String.t(),
            chain: atom(),
            chain_id: pos_integer(),
            block_number: non_neg_integer(),
            tx_hash: String.t() | nil,
            log_index: non_neg_integer(),
            contract_address: String.t(),
            topic0: String.t() | nil,
            event_name: String.t(),
            topics: [String.t()],
            data: String.t(),
            decoded_params: map(),
            timestamp: non_neg_integer()
          }

    defstruct id: nil,
              chain: :ethereum,
              chain_id: 1,
              block_number: 0,
              tx_hash: nil,
              log_index: 0,
              contract_address: nil,
              topic0: nil,
              event_name: "UnknownEvent",
              topics: [],
              data: "0x",
              decoded_params: %{},
              timestamp: 0
  end

  @doc """
  Normalizes a raw JSON-RPC block map into `%NormalizedBlock{}` and its embedded
  `%NormalizedTransaction{}` entries.
  """
  @spec normalize_block(atom(), pos_integer(), map()) :: NormalizedBlock.t()
  def normalize_block(chain, chain_id, raw_block) when is_map(raw_block) do
    block_number = hex_to_int(raw_block["number"])
    timestamp = hex_to_int(raw_block["timestamp"])
    raw_txs = Map.get(raw_block, "transactions") || []

    normalized_txs =
      raw_txs
      |> Enum.filter(&is_map/1)
      |> Enum.map(&normalize_transaction(chain, chain_id, &1, block_number, timestamp))

    %NormalizedBlock{
      chain: chain,
      chain_id: chain_id,
      block_number: block_number,
      block_hash: downcase_str(raw_block["hash"]),
      parent_hash: downcase_str(raw_block["parentHash"]),
      timestamp: timestamp,
      gas_used: hex_to_int(raw_block["gasUsed"]),
      gas_limit: hex_to_int(raw_block["gasLimit"]),
      base_fee_per_gas:
        if(raw_block["baseFeePerGas"], do: hex_to_int(raw_block["baseFeePerGas"]), else: nil),
      tx_count: length(raw_txs),
      transactions: normalized_txs
    }
  end

  @doc """
  Normalizes a raw JSON-RPC transaction map into `%NormalizedTransaction{}`.
  """
  @spec normalize_transaction(
          atom(),
          pos_integer(),
          map(),
          non_neg_integer() | nil,
          non_neg_integer()
        ) :: NormalizedTransaction.t()
  def normalize_transaction(chain, chain_id, raw_tx, fallback_block \\ nil, timestamp \\ 0)
      when is_map(raw_tx) do
    block_num =
      if raw_tx["blockNumber"],
        do: hex_to_int(raw_tx["blockNumber"]),
        else: fallback_block || 0

    %NormalizedTransaction{
      chain: chain,
      chain_id: chain_id,
      tx_hash: downcase_str(raw_tx["hash"]),
      block_number: block_num,
      from: downcase_str(raw_tx["from"]),
      to: downcase_str(raw_tx["to"]),
      value_wei: hex_to_int(raw_tx["value"]),
      gas: hex_to_int(raw_tx["gas"]),
      gas_price_wei: hex_to_int(raw_tx["gasPrice"] || raw_tx["maxFeePerGas"]),
      nonce: hex_to_int(raw_tx["nonce"]),
      input: raw_tx["input"] || "0x",
      timestamp: timestamp
    }
  end

  @doc """
  Normalizes a raw JSON-RPC log entry (`eth_getLogs`) into `%NormalizedEvent{}`
  including automatic decoding of common ERC-20, ERC-721, and DEX events.
  """
  @spec normalize_event(atom(), pos_integer(), map(), non_neg_integer()) :: NormalizedEvent.t()
  def normalize_event(chain, chain_id, raw_log, timestamp \\ 0) when is_map(raw_log) do
    topics = Enum.map(raw_log["topics"] || [], &downcase_str/1)
    topic0 = List.first(topics)
    block_number = hex_to_int(raw_log["blockNumber"])
    log_index = hex_to_int(raw_log["logIndex"])
    tx_hash = downcase_str(raw_log["transactionHash"])
    data = raw_log["data"] || "0x"
    {event_name, decoded_params} = decode_known_event(topic0, topics, data)

    %NormalizedEvent{
      id: "#{chain}:#{block_number}:#{tx_hash}:#{log_index}",
      chain: chain,
      chain_id: chain_id,
      block_number: block_number,
      tx_hash: tx_hash,
      log_index: log_index,
      contract_address: downcase_str(raw_log["address"]),
      topic0: topic0,
      event_name: event_name,
      topics: topics,
      data: data,
      decoded_params: decoded_params,
      timestamp: timestamp
    }
  end

  @doc """
  Converts a `0x`-prefixed hex quantity or integer to a non-negative integer.
  """
  @spec hex_to_int(term()) :: non_neg_integer()
  def hex_to_int(val) when is_integer(val) and val >= 0, do: val
  def hex_to_int("0x" <> hex) when byte_size(hex) > 0 do
    case Integer.parse(hex, 16) do
      {num, ""} when num >= 0 -> num
      _ -> 0
    end
  end

  def hex_to_int(_), do: 0

  @doc """
  Converts a non-negative integer to a `0x`-prefixed hex string.
  """
  @spec int_to_hex(non_neg_integer()) :: String.t()
  def int_to_hex(0), do: "0x0"

  def int_to_hex(val) when is_integer(val) and val > 0 do
    "0x" <> String.downcase(Integer.to_string(val, 16))
  end

  defp decode_known_event(@transfer_topic, [_topic0, from_topic, to_topic | _], data) do
    {
      "Transfer",
      %{
        from: topic_to_address(from_topic),
        to: topic_to_address(to_topic),
        value: hex_to_int(data)
      }
    }
  end

  defp decode_known_event(@approval_topic, [_topic0, owner_topic, spender_topic | _], data) do
    {
      "Approval",
      %{
        owner: topic_to_address(owner_topic),
        spender: topic_to_address(spender_topic),
        value: hex_to_int(data)
      }
    }
  end

  defp decode_known_event(@swap_topic, [_topic0, sender_topic | rest], data) do
    {
      "Swap",
      %{
        sender: topic_to_address(sender_topic),
        recipient: topic_to_address(List.first(rest)),
        raw_data: data
      }
    }
  end

  defp decode_known_event(_topic0, _topics, _data), do: {"ContractEvent", %{}}

  defp topic_to_address("0x" <> hex) when byte_size(hex) == 64 do
    "0x" <> String.slice(hex, 24, 40)
  end

  defp topic_to_address(other), do: other

  defp downcase_str(nil), do: nil
  defp downcase_str(val) when is_binary(val), do: String.downcase(val)
end
