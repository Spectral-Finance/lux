defmodule Lux.Web3.Multichain.Schemas do
  @moduledoc """
  Unified data schemas and normalization functions for multi-chain EVM data aggregation (#74).

  Normalizes heterogeneous JSON-RPC data structures across Ethereum, BSC, Polygon,
  Arbitrum, Optimism, Base, Avalanche, and other EVM-compatible networks into consistent,
  strongly-typed Elixir structs.
  """

  defmodule Block do
    @moduledoc "Normalized block representation across multi-chain EVM networks."
    @enforce_keys [:chain_id, :chain, :number, :hash, :timestamp]
    defstruct [
      :chain_id,
      :chain,
      :number,
      :hash,
      :parent_hash,
      :timestamp,
      :gas_used,
      :gas_limit,
      :base_fee_per_gas,
      :transaction_count,
      transactions: []
    ]

    @type t :: %__MODULE__{
            chain_id: non_neg_integer(),
            chain: atom(),
            number: non_neg_integer(),
            hash: String.t(),
            parent_hash: String.t() | nil,
            timestamp: non_neg_integer(),
            gas_used: non_neg_integer() | nil,
            gas_limit: non_neg_integer() | nil,
            base_fee_per_gas: non_neg_integer() | nil,
            transaction_count: non_neg_integer(),
            transactions: list()
          }
  end

  defmodule Transaction do
    @moduledoc "Normalized transaction representation across multi-chain EVM networks."
    @enforce_keys [:chain_id, :chain, :hash, :block_number, :from]
    defstruct [
      :chain_id,
      :chain,
      :hash,
      :block_number,
      :from,
      :to,
      :value,
      :gas_price,
      :gas_used,
      :nonce,
      :status,
      :input_data
    ]

    @type t :: %__MODULE__{
            chain_id: non_neg_integer(),
            chain: atom(),
            hash: String.t(),
            block_number: non_neg_integer(),
            from: String.t(),
            to: String.t() | nil,
            value: non_neg_integer(),
            gas_price: non_neg_integer() | nil,
            gas_used: non_neg_integer() | nil,
            nonce: non_neg_integer() | nil,
            status: :success | :reverted | :pending,
            input_data: String.t() | nil
          }
  end

  defmodule Event do
    @moduledoc "Normalized smart contract event log across multi-chain EVM networks."
    @enforce_keys [:chain_id, :chain, :contract_address, :block_number, :tx_hash]
    defstruct [
      :chain_id,
      :chain,
      :contract_address,
      :event_name,
      :block_number,
      :tx_hash,
      :log_index,
      :topics,
      :data,
      decoded_params: %{}
    ]

    @type t :: %__MODULE__{
            chain_id: non_neg_integer(),
            chain: atom(),
            contract_address: String.t(),
            event_name: String.t() | nil,
            block_number: non_neg_integer(),
            tx_hash: String.t(),
            log_index: non_neg_integer() | nil,
            topics: [String.t()],
            data: String.t() | nil,
            decoded_params: map()
          }
  end

  defmodule TokenTransfer do
    @moduledoc "Normalized ERC-20 / ERC-721 token transfer across multi-chain EVM networks."
    @enforce_keys [:chain_id, :chain, :token_address, :from, :to, :block_number, :tx_hash]
    defstruct [
      :chain_id,
      :chain,
      :token_address,
      :token_standard,
      :from,
      :to,
      :amount,
      :token_id,
      :block_number,
      :tx_hash
    ]

    @type t :: %__MODULE__{
            chain_id: non_neg_integer(),
            chain: atom(),
            token_address: String.t(),
            token_standard: :erc20 | :erc721 | :erc1155,
            from: String.t(),
            to: String.t(),
            amount: non_neg_integer() | nil,
            token_id: non_neg_integer() | nil,
            block_number: non_neg_integer(),
            tx_hash: String.t()
          }
  end

  @doc """
  Normalizes raw JSON-RPC block data into a `%Block{}` struct.
  Handles hex-encoded numbers, lowercase addresses, and nested transaction lists.
  """
  @spec normalize_block(map(), atom(), non_neg_integer()) :: {:ok, Block.t()} | {:error, term()}
  def normalize_block(raw, chain, chain_id) when is_map(raw) and is_atom(chain) do
    number = parse_int(raw[:number] || raw["number"])
    hash = raw[:hash] || raw["hash"]
    timestamp = parse_int(raw[:timestamp] || raw["timestamp"])

    if is_nil(number) or is_nil(hash) do
      {:error, :invalid_block_payload}
    else
      raw_txs = raw[:transactions] || raw["transactions"] || []

      normalized_txs =
        Enum.map(raw_txs, fn
          tx when is_map(tx) ->
            case normalize_transaction(tx, chain, chain_id) do
              {:ok, norm} -> norm
              _ -> nil
            end

          tx_hash when is_binary(tx_hash) ->
            tx_hash

          _ ->
            nil
        end)
        |> Enum.reject(&is_nil/1)

      {:ok,
       %Block{
         chain_id: chain_id,
         chain: chain,
         number: number,
         hash: String.downcase(to_string(hash)),
         parent_hash: normalize_hash(raw[:parentHash] || raw["parentHash"]),
         timestamp: timestamp || 0,
         gas_used: parse_int(raw[:gasUsed] || raw["gasUsed"]),
         gas_limit: parse_int(raw[:gasLimit] || raw["gasLimit"]),
         base_fee_per_gas: parse_int(raw[:baseFeePerGas] || raw["baseFeePerGas"]),
         transaction_count: length(raw_txs),
         transactions: normalized_txs
       }}
    end
  end

  @doc """
  Normalizes raw JSON-RPC transaction data into a `%Transaction{}` struct.
  """
  @spec normalize_transaction(map(), atom(), non_neg_integer()) ::
          {:ok, Transaction.t()} | {:error, term()}
  def normalize_transaction(raw, chain, chain_id) when is_map(raw) and is_atom(chain) do
    hash = raw[:hash] || raw["hash"]
    block_num = parse_int(raw[:blockNumber] || raw["blockNumber"])
    from = raw[:from] || raw["from"]

    if is_nil(hash) or is_nil(from) do
      {:error, :invalid_transaction_payload}
    else
      to = raw[:to] || raw["to"]
      value = parse_int(raw[:value] || raw["value"]) || 0
      gas_price = parse_int(raw[:gasPrice] || raw["gasPrice"])
      gas_used = parse_int(raw[:gas] || raw["gas"] || raw[:gasUsed] || raw["gasUsed"])
      nonce = parse_int(raw[:nonce] || raw["nonce"])
      raw_status = raw[:status] || raw["status"]

      status =
        case raw_status do
          s when s in [1, "0x1", "1", true] -> :success
          s when s in [0, "0x0", "0", false] -> :reverted
          _ -> :pending
        end

      {:ok,
       %Transaction{
         chain_id: chain_id,
         chain: chain,
         hash: String.downcase(to_string(hash)),
         block_number: block_num || 0,
         from: String.downcase(to_string(from)),
         to: if(to, do: String.downcase(to_string(to)), else: nil),
         value: value,
         gas_price: gas_price,
         gas_used: gas_used,
         nonce: nonce,
         status: status,
         input_data: raw[:input] || raw["input"] || raw[:data] || raw["data"]
       }}
    end
  end

  @doc """
  Normalizes raw log receipt into a `%Event{}` struct.
  """
  @spec normalize_event(map(), atom(), non_neg_integer(), map()) ::
          {:ok, Event.t()} | {:error, term()}
  def normalize_event(raw, chain, chain_id, decoded_params \\ %{})
      when is_map(raw) and is_atom(chain) do
    contract = raw[:address] || raw["address"]
    tx_hash = raw[:transactionHash] || raw["transactionHash"]
    block_num = parse_int(raw[:blockNumber] || raw["blockNumber"])

    if is_nil(contract) or is_nil(tx_hash) do
      {:error, :invalid_event_payload}
    else
      topics =
        (raw[:topics] || raw["topics"] || [])
        |> Enum.map(&String.downcase(to_string(&1)))

      {:ok,
       %Event{
         chain_id: chain_id,
         chain: chain,
         contract_address: String.downcase(to_string(contract)),
         event_name: raw[:event_name] || raw["event_name"],
         block_number: block_num || 0,
         tx_hash: String.downcase(to_string(tx_hash)),
         log_index: parse_int(raw[:logIndex] || raw["logIndex"]),
         topics: topics,
         data: raw[:data] || raw["data"],
         decoded_params: decoded_params
       }}
    end
  end

  @doc """
  Parses hex or decimal integers into native Elixir integers.
  """
  @spec parse_int(term()) :: non_neg_integer() | nil
  def parse_int(nil), do: nil
  def parse_int(val) when is_integer(val), do: val

  def parse_int(val) when is_binary(val) do
    trimmed = String.trim(val)

    cond do
      String.starts_with?(trimmed, "0x") or String.starts_with?(trimmed, "0X") ->
        case Integer.parse(String.slice(trimmed, 2..-1//1), 16) do
          {num, ""} -> num
          _ -> nil
        end

      true ->
        case Integer.parse(trimmed, 10) do
          {num, ""} -> num
          _ -> nil
        end
    end
  end

  def parse_int(_), do: nil

  defp normalize_hash(nil), do: nil
  defp normalize_hash(val), do: String.downcase(to_string(val))
end
