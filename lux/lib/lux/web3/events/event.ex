defmodule Lux.Web3.Events.Event do
  @moduledoc """
  Structured representation of a blockchain event/log.

  Provides a normalized schema for events fetched from any chain
  via Etherscan or direct RPC, with support for indexed (topic) and
  non-indexed (data) parameters.
  """

  use Lux.Types

  defstruct chain_id: 1,
            contract_address: "",
            transaction_hash: "",
            block_number: 0,
            block_hash: "",
            log_index: 0,
            transaction_index: 0,
            topic0: "",
            topics: [],
            data: "",
            decoded_params: %{},
            timestamp: 0,
            gas_used: 0,
            raw: %{}

  @type t :: %__MODULE__{
          chain_id: pos_integer(),
          contract_address: String.t(),
          transaction_hash: String.t(),
          block_number: non_neg_integer(),
          block_hash: String.t(),
          log_index: non_neg_integer(),
          transaction_index: non_neg_integer(),
          topic0: String.t(),
          topics: [String.t()],
          data: String.t(),
          decoded_params: map(),
          timestamp: non_neg_integer(),
          gas_used: non_neg_integer(),
          raw: map()
        }

  @doc """
  Converts a raw Etherscan log entry into an Event struct.
  """
  @spec from_raw(raw :: map(), chain_id :: pos_integer()) :: t()
  def from_raw(raw, chain_id \ 1) do
    topics = Map.get(raw, "topics", [])

    %__MODULE__{
      chain_id: chain_id,
      contract_address: Map.get(raw, "address", ""),
      transaction_hash: Map.get(raw, "transaction_hash", Map.get(raw, "transactionHash", "")),
      block_number: parse_hex_or_dec(Map.get(raw, "block_number", Map.get(raw, "blockNumber", "0"))),
      block_hash: Map.get(raw, "blockHash", ""),
      log_index: parse_hex_or_dec(Map.get(raw, "log_index", Map.get(raw, "logIndex", "0"))),
      transaction_index: parse_hex_or_dec(Map.get(raw, "transaction_index", Map.get(raw, "transactionIndex", "0"))),
      topic0: List.first(topics) || "",
      topics: topics,
      data: Map.get(raw, "data", ""),
      decoded_params: Map.get(raw, "decoded_params", %{}),
      timestamp: parse_hex_or_dec(Map.get(raw, "timestamp", Map.get(raw, "timeStamp", "0"))),
      gas_used: parse_hex_or_dec(Map.get(raw, "gas_used", Map.get(raw, "gasUsed", "0"))),
      raw: raw
    }
  end

  @doc """
  Parses a hex or decimal string to an integer.
  """
  @spec parse_hex_or_dec(String.t()) :: non_neg_integer()
  def parse_hex_or_dec(value) when is_binary(value) do
    cond do
      String.starts_with?(value, "0x") ->
        case Integer.parse(value, 16) do
          {num, ""} -> num
          {_num, _rest} -> 0
          :error -> 0
        end

      Regex.match?(~r/^\d+$/, value) ->
        case Integer.parse(value) do
          {num, ""} -> num
          :error -> 0
        end

      true ->
        0
    end
  end

  def parse_hex_or_dec(value) when is_integer(value), do: value
  def parse_hex_or_dec(_), do: 0

  @doc """
  Checks if this event matches a given topic filter.
  """
  @spec matches_topic_filter?(t(), [String.t() | :any]) :: boolean()
  def matches_topic_filter?(event, filters) do
    Enum.all?(filters, fn
      :any -> true
      nil -> true
      filter -> event.topic0 == filter
    end)
  end

  @doc """
  Serializes an event to a map suitable for persistence.
  """
  @spec to_map(t()) :: map()
  def to_map(event) do
    Map.from_struct(event)
  end
end
