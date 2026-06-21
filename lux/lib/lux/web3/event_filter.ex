defmodule Lux.Web3.EventFilter do
  @moduledoc """
  ABI event signature parsing and log decoding utilities.

  Provides functions to:
    - Encode Solidity event signatures into Keccak-256 topic hashes
    - Build `eth_getLogs` filter parameters from high-level specifications
    - Decode raw EVM log entries into structured event data
    - Match logs against filter criteria for pattern-based event selection
  """

  require Logger

  @type event_signature :: String.t()
  @type topic :: String.t()
  @type log_entry :: map()
  @type decoded_event :: map()
  @type filter_params :: map()

  # ── Signature Encoding ──────────────────────────────────────────────

  @doc """
  Encodes a Solidity event signature (e.g. `"Transfer(address,address,uint256)"`)
  into its Keccak-256 topic hash prefixed with `"0x"`.

  ## Examples

      iex> Lux.Web3.EventFilter.encode_event_signature("Transfer(address,address,uint256)")
      "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
  """
  @spec encode_event_signature(event_signature()) :: topic()
  def encode_event_signature(signature) when is_binary(signature) do
    signature
    |> keccak256()
    |> Base.encode16(case: :lower)
    |> then(&("0x" <> &1))
  end

  @doc """
  Parses an event signature string into its name and parameter types.

  ## Examples

      iex> Lux.Web3.EventFilter.parse_signature("Transfer(address,address,uint256)")
      {:ok, %{name: "Transfer", param_types: ["address", "address", "uint256"]}}
  """
  @spec parse_signature(event_signature()) :: {:ok, map()} | {:error, String.t()}
  def parse_signature(signature) when is_binary(signature) do
    case Regex.run(~r/^(\w+)\((.*)\)$/, signature) do
      [_, name, params_str] ->
        param_types =
          params_str
          |> String.split(",", trim: true)
          |> Enum.map(&String.trim/1)

        {:ok, %{name: name, param_types: param_types}}

      _ ->
        {:error, "Invalid event signature format: #{signature}"}
    end
  end

  # ── Filter Building ──────────────────────────────────────────────────

  @doc """
  Builds `eth_getLogs` filter parameters from a high-level filter specification.

  ## Options

    * `:contract_address` – the contract address (hex string, required)
    * `:event_signatures` – list of event signature strings to filter by
    * `:from_block`       – start block (`"latest"`, `"earliest"`, or hex string)
    * `:to_block`         – end block (`"latest"`, `"earliest"`, or hex string)
    * `:topics`           – additional topic filters (list of topic values or nil)

  ## Examples

      iex> Lux.Web3.EventFilter.build_filter(%{
      ...>   contract_address: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
      ...>   event_signatures: ["Transfer(address,address,uint256)"],
      ...>   from_block: "0x0",
      ...>   to_block: "latest"
      ...> })
      {:ok, %{...}}
  """
  @spec build_filter(map()) :: {:ok, filter_params()} | {:error, String.t()}
  def build_filter(%{contract_address: address} = opts) when is_binary(address) do
    from_block = Map.get(opts, :from_block, "latest")
    to_block = Map.get(opts, :to_block, "latest")

    topics = build_topics(opts)

    filter = %{
      "address" => address,
      "fromBlock" => normalize_block(from_block),
      "toBlock" => normalize_block(to_block),
      "topics" => topics
    }

    {:ok, filter}
  end

  def build_filter(_), do: {:error, "contract_address is required"}

  @doc """
  Builds a filter suitable for `eth_subscribe` with the `"logs"` subscription type.
  """
  @spec build_subscription_filter(map()) :: {:ok, map()} | {:error, String.t()}
  def build_subscription_filter(%{contract_address: address} = opts) when is_binary(address) do
    topics = build_topics(opts)

    filter = %{
      "address" => address,
      "topics" => topics
    }

    {:ok, filter}
  end

  def build_subscription_filter(_), do: {:error, "contract_address is required"}

  # ── Log Decoding ───────────────────────────────────────────────────

  @doc """
  Decodes a raw EVM log entry into a structured event map.

  Returns a map with:
    * `:event_signature` – the topic0 hash
    * `:contract_address` – emitting contract
    * `:block_number` – block where the event was emitted
    * `:transaction_hash` – originating transaction
    * `:log_index` – position in the block's log list
    * `:topics` – decoded indexed parameters
    * `:data` – raw non-indexed data
    * `:decoded_data` – hex-decoded data segments
    * `:removed` – whether the log was removed due to a reorg
  """
  @spec decode_log(log_entry()) :: {:ok, decoded_event()} | {:error, String.t()}
  def decode_log(%{"topics" => [topic0 | indexed_topics]} = log) do
    decoded = %{
      event_signature: topic0,
      contract_address: log["address"],
      block_number: hex_to_integer(log["blockNumber"]),
      transaction_hash: log["transactionHash"],
      log_index: hex_to_integer(log["logIndex"]),
      topics: decode_indexed_topics(indexed_topics),
      data: log["data"],
      decoded_data: decode_data(log["data"]),
      removed: Map.get(log, "removed", false),
      block_hash: log["blockHash"],
      transaction_index: hex_to_integer(log["transactionIndex"])
    }

    {:ok, decoded}
  end

  def decode_log(%{"topics" => []}), do: {:error, "Log has no topics (anonymous event)"}
  def decode_log(_), do: {:error, "Invalid log entry format"}

  @doc """
  Decodes a batch of log entries, returning only successfully decoded events.
  """
  @spec decode_logs([log_entry()]) :: [decoded_event()]
  def decode_logs(logs) when is_list(logs) do
    logs
    |> Enum.map(&decode_log/1)
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, event} -> event end)
  end

  # ── Pattern Matching ───────────────────────────────────────────────

  @doc """
  Checks whether a decoded event matches the given filter criteria.

  Supported filter keys:
    * `:event_signatures` – list of event signature strings
    * `:contract_address` – specific contract address
    * `:min_block` – minimum block number (inclusive)
    * `:max_block` – maximum block number (inclusive)
  """
  @spec matches?(decoded_event(), map()) :: boolean()
  def matches?(event, filter \\ %{})

  def matches?(event, filter) do
    matches_signatures?(event, filter) and
      matches_address?(event, filter) and
      matches_block_range?(event, filter)
  end

  # ── Private Helpers ────────────────────────────────────────────────

  defp build_topics(opts) do
    event_sigs = Map.get(opts, :event_signatures, [])
    extra_topics = Map.get(opts, :topics, [])

    topic0 =
      case event_sigs do
        [] -> nil
        [single] -> encode_event_signature(single)
        multiple -> Enum.map(multiple, &encode_event_signature/1)
      end

    [topic0 | extra_topics]
  end

  defp decode_indexed_topics(topics) do
    Enum.map(topics, fn topic ->
      %{
        raw: topic,
        as_address: decode_topic_as_address(topic),
        as_integer: hex_to_integer(topic)
      }
    end)
  end

  defp decode_topic_as_address("0x" <> hex) when byte_size(hex) == 64 do
    # Addresses are 20 bytes, left-padded to 32 bytes in topics
    "0x" <> String.slice(hex, 24, 40)
  end

  defp decode_topic_as_address(topic), do: topic

  defp decode_data("0x" <> hex) when byte_size(hex) > 0 do
    hex
    |> String.graphemes()
    |> Enum.chunk_every(64)
    |> Enum.map(&Enum.join/1)
    |> Enum.map(fn chunk -> "0x" <> chunk end)
  end

  defp decode_data(_), do: []

  defp normalize_block(block) when is_integer(block) do
    "0x" <> Integer.to_string(block, 16)
  end

  defp normalize_block("0x" <> _ = block), do: block
  defp normalize_block("latest"), do: "latest"
  defp normalize_block("earliest"), do: "earliest"
  defp normalize_block("pending"), do: "pending"

  defp normalize_block(block) when is_binary(block) do
    case Integer.parse(block) do
      {num, ""} -> "0x" <> Integer.to_string(num, 16)
      _ -> block
    end
  end

  defp hex_to_integer(nil), do: nil
  defp hex_to_integer("0x" <> hex), do: String.to_integer(hex, 16)
  defp hex_to_integer(hex) when is_binary(hex), do: String.to_integer(hex, 16)
  defp hex_to_integer(int) when is_integer(int), do: int

  defp matches_signatures?(_event, %{event_signatures: []}), do: true
  defp matches_signatures?(_event, filter) when not is_map_key(filter, :event_signatures), do: true

  defp matches_signatures?(event, %{event_signatures: sigs}) do
    encoded_sigs = Enum.map(sigs, &encode_event_signature/1)
    event.event_signature in encoded_sigs
  end

  defp matches_address?(_event, filter) when not is_map_key(filter, :contract_address), do: true

  defp matches_address?(event, %{contract_address: address}) do
    String.downcase(event.contract_address) == String.downcase(address)
  end

  defp matches_block_range?(event, filter) do
    min_ok =
      case Map.get(filter, :min_block) do
        nil -> true
        min -> event.block_number >= min
      end

    max_ok =
      case Map.get(filter, :max_block) do
        nil -> true
        max -> event.block_number <= max
      end

    min_ok and max_ok
  end

  defp keccak256(data) do
    ExKeccak.hash_256(data)
  end
end
