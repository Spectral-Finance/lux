defmodule Lux.EventMonitor.EventLog do
  @moduledoc """
  Represents a parsed and decoded smart contract event log.

  An EventLog contains the raw blockchain log data along with decoded
  event parameters when an ABI is available.

  ## Fields

    * `address` - The contract address that emitted the event
    * `topics` - Raw topic hashes from the log
    * `data` - Raw data field from the log
    * `block_number` - Block number where the event was emitted
    * `block_hash` - Hash of the block
    * `transaction_hash` - Hash of the transaction that triggered the event
    * `transaction_index` - Index of the transaction in the block
    * `log_index` - Index of the log in the block
    * `timestamp` - Block timestamp (if available)
    * `event_name` - Decoded event name (if ABI is available)
    * `decoded_params` - Decoded event parameters (if ABI is available)
    * `chain_id` - Chain identifier
    * `removed` - Whether the log was removed due to a chain reorg
  """

  @type t :: %__MODULE__{
          address: String.t(),
          topics: [String.t()],
          data: String.t(),
          block_number: non_neg_integer(),
          block_hash: String.t() | nil,
          transaction_hash: String.t(),
          transaction_index: non_neg_integer() | nil,
          log_index: non_neg_integer(),
          timestamp: non_neg_integer() | nil,
          event_name: String.t() | nil,
          decoded_params: map() | nil,
          chain_id: pos_integer(),
          removed: boolean()
        }

  defstruct [
    :address,
    :topics,
    :data,
    :block_number,
    :block_hash,
    :transaction_hash,
    :transaction_index,
    :log_index,
    :timestamp,
    :event_name,
    :decoded_params,
    :chain_id,
    removed: false
  ]

  @doc """
  Creates a new EventLog from a raw log map returned by an RPC or Etherscan response.

  ## Parameters

    * `raw` - A map with string keys from an API response
    * `opts` - Options including `:chain_id` (default 1)

  ## Examples

      iex> Lux.EventMonitor.EventLog.from_raw(%{
      ...>   "address" => "0xdead...",
      ...>   "topics" => ["0xddf2..."],
      ...>   "data" => "0x",
      ...>   "blockNumber" => "0x10",
      ...>   "transactionHash" => "0xabc...",
      ...>   "logIndex" => "0x0"
      ...> })
      %Lux.EventMonitor.EventLog{address: "0xdead...", ...}
  """
  @spec from_raw(map(), keyword()) :: t()
  def from_raw(raw, opts \\ []) do
    chain_id = Keyword.get(opts, :chain_id, 1)

    %__MODULE__{
      address: Map.get(raw, "address", ""),
      topics: Map.get(raw, "topics", []),
      data: Map.get(raw, "data", "0x"),
      block_number: parse_hex_or_int(Map.get(raw, "blockNumber", 0)),
      block_hash: Map.get(raw, "blockHash"),
      transaction_hash: Map.get(raw, "transactionHash", ""),
      transaction_index: parse_hex_or_int(Map.get(raw, "transactionIndex")),
      log_index: parse_hex_or_int(Map.get(raw, "logIndex", 0)),
      timestamp: parse_hex_or_int(Map.get(raw, "timeStamp")),
      chain_id: chain_id,
      removed: Map.get(raw, "removed", false)
    }
  end

  @doc """
  Returns the event signature topic (topic0), which is the keccak256 hash
  of the event signature.
  """
  @spec event_signature(t()) :: String.t() | nil
  def event_signature(%__MODULE__{topics: [sig | _]}), do: sig
  def event_signature(_), do: nil

  @doc """
  Returns a unique identifier for this event log, combining the transaction hash
  and log index.
  """
  @spec unique_id(t()) :: String.t()
  def unique_id(%__MODULE__{transaction_hash: tx_hash, log_index: idx}) do
    "#{tx_hash}:#{idx}"
  end

  @doc """
  Checks if this event log matches a given topic filter.

  The filter is a list of topic positions and expected values. Each element is
  either a specific topic value string or `nil` to match any value.

  ## Examples

      iex> log = %Lux.EventMonitor.EventLog{topics: ["0xddf2...", "0x0001..."]}
      iex> Lux.EventMonitor.EventLog.matches_topics?(log, ["0xddf2...", nil])
      true
  """
  @spec matches_topics?(t(), [String.t() | nil]) :: boolean()
  def matches_topics?(%__MODULE__{topics: topics}, filter) when is_list(filter) do
    filter
    |> Enum.with_index()
    |> Enum.all?(fn
      {nil, _index} -> true
      {expected, index} -> Enum.at(topics, index) == expected
    end)
  end

  def matches_topics?(_, _), do: true

  # Parse hex strings ("0x10") or integers, returning nil for nil inputs
  defp parse_hex_or_int(nil), do: nil
  defp parse_hex_or_int(val) when is_integer(val), do: val

  defp parse_hex_or_int("0x" <> hex) do
    {val, _} = Integer.parse(hex, 16)
    val
  end

  defp parse_hex_or_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {num, _} -> num
      :error -> nil
    end
  end

  defp parse_hex_or_int(_), do: nil
end
