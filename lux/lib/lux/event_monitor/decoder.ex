defmodule Lux.EventMonitor.Decoder do
  @moduledoc """
  Decodes raw event log data using contract ABIs.

  The Decoder takes raw event logs and an ABI definition to produce
  human-readable event names and decoded parameter values.

  ## ABI Format

  The ABI should be provided as a list of event definitions:

      [
        %{
          "type" => "event",
          "name" => "Transfer",
          "inputs" => [
            %{"name" => "from", "type" => "address", "indexed" => true},
            %{"name" => "to", "type" => "address", "indexed" => true},
            %{"name" => "value", "type" => "uint256", "indexed" => false}
          ]
        }
      ]

  ## Usage

      iex> abi = [%{"type" => "event", "name" => "Transfer", "inputs" => [...]}]
      iex> decoder = Lux.EventMonitor.Decoder.new(abi)
      iex> Lux.EventMonitor.Decoder.decode_log(decoder, event_log)
      %Lux.EventMonitor.EventLog{event_name: "Transfer", decoded_params: %{...}}
  """

  alias Lux.EventMonitor.EventLog

  @type event_def :: %{
          name: String.t(),
          signature: String.t(),
          topic: String.t(),
          indexed_inputs: [map()],
          data_inputs: [map()]
        }

  @type t :: %__MODULE__{
          events_by_topic: %{String.t() => event_def()}
        }

  defstruct events_by_topic: %{}

  @doc """
  Creates a new Decoder from a contract ABI.

  Extracts event definitions and computes keccak256 topic hashes for each event
  to enable efficient lookup during decoding.

  ## Parameters

    * `abi` - A list of ABI entry maps. Only entries with `"type" => "event"` are processed.

  ## Examples

      iex> abi = [%{"type" => "event", "name" => "Transfer", "inputs" => [
      ...>   %{"name" => "from", "type" => "address", "indexed" => true},
      ...>   %{"name" => "to", "type" => "address", "indexed" => true},
      ...>   %{"name" => "value", "type" => "uint256", "indexed" => false}
      ...> ]}]
      iex> decoder = Lux.EventMonitor.Decoder.new(abi)
      iex> map_size(decoder.events_by_topic)
      1
  """
  @spec new([map()]) :: t()
  def new(abi) when is_list(abi) do
    events =
      abi
      |> Enum.filter(&(Map.get(&1, "type") == "event"))
      |> Enum.map(&parse_event_def/1)
      |> Map.new(fn event_def -> {event_def.topic, event_def} end)

    %__MODULE__{events_by_topic: events}
  end

  def new(_), do: %__MODULE__{}

  @doc """
  Decodes an EventLog using this decoder's ABI.

  If the event's topic0 matches a known event signature, the event name
  and decoded parameters are populated. Unknown events are returned unchanged.

  ## Parameters

    * `decoder` - A Decoder struct
    * `event_log` - An EventLog to decode

  ## Returns

  An EventLog with `event_name` and `decoded_params` populated if decoding succeeds.
  """
  @spec decode_log(t(), EventLog.t()) :: EventLog.t()
  def decode_log(%__MODULE__{events_by_topic: events}, %EventLog{} = event_log) do
    case EventLog.event_signature(event_log) do
      nil ->
        event_log

      topic0 ->
        case Map.get(events, topic0) do
          nil ->
            event_log

          event_def ->
            decoded = decode_params(event_def, event_log)

            %EventLog{
              event_log
              | event_name: event_def.name,
                decoded_params: decoded
            }
        end
    end
  end

  @doc """
  Decodes a batch of EventLogs.
  """
  @spec decode_logs(t(), [EventLog.t()]) :: [EventLog.t()]
  def decode_logs(%__MODULE__{} = decoder, logs) when is_list(logs) do
    Enum.map(logs, &decode_log(decoder, &1))
  end

  @doc """
  Computes the keccak256 hash of an event signature string.

  ## Examples

      iex> Lux.EventMonitor.Decoder.event_topic("Transfer(address,address,uint256)")
      "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
  """
  @spec event_topic(String.t()) :: String.t()
  def event_topic(signature) when is_binary(signature) do
    hash =
      ExKeccak.hash_256(signature)
      |> Base.encode16(case: :lower)

    "0x" <> hash
  end

  @doc """
  Lists all known event names from this decoder.
  """
  @spec known_events(t()) :: [String.t()]
  def known_events(%__MODULE__{events_by_topic: events}) do
    events
    |> Map.values()
    |> Enum.map(& &1.name)
    |> Enum.sort()
  end

  # Parse an ABI event definition into our internal format
  defp parse_event_def(event_entry) do
    name = Map.get(event_entry, "name", "")
    inputs = Map.get(event_entry, "inputs", [])

    # Build signature like "Transfer(address,address,uint256)"
    param_types = Enum.map_join(inputs, ",", &Map.get(&1, "type", ""))
    signature = "#{name}(#{param_types})"
    topic = event_topic(signature)

    {indexed, data} = Enum.split_with(inputs, &Map.get(&1, "indexed", false))

    %{
      name: name,
      signature: signature,
      topic: topic,
      indexed_inputs: indexed,
      data_inputs: data
    }
  end

  # Decode event parameters from topics and data
  defp decode_params(event_def, %EventLog{topics: topics, data: data}) do
    indexed_params = decode_indexed_params(event_def.indexed_inputs, tl(topics || []))
    data_params = decode_data_params(event_def.data_inputs, data)

    Map.merge(indexed_params, data_params)
  end

  # Decode indexed parameters from topics (topic1, topic2, etc.)
  defp decode_indexed_params(inputs, topics) do
    inputs
    |> Enum.zip(topics ++ List.duplicate(nil, max(0, length(inputs) - length(topics))))
    |> Enum.reduce(%{}, fn {input, topic_value}, acc ->
      name = Map.get(input, "name", "unknown")
      type = Map.get(input, "type", "bytes32")
      decoded = decode_topic_value(type, topic_value)
      Map.put(acc, name, decoded)
    end)
  end

  # Decode non-indexed parameters from the data field
  defp decode_data_params(_inputs, nil), do: %{}
  defp decode_data_params(_inputs, "0x"), do: %{}
  defp decode_data_params([], _data), do: %{}

  defp decode_data_params(inputs, "0x" <> hex_data) do
    # Each ABI-encoded parameter is 32 bytes (64 hex chars)
    chunks = chunk_hex(hex_data, 64)

    inputs
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {input, index}, acc ->
      name = Map.get(input, "name", "param_#{index}")
      type = Map.get(input, "type", "bytes32")
      chunk = Enum.at(chunks, index, "0")
      decoded = decode_data_value(type, chunk)
      Map.put(acc, name, decoded)
    end)
  end

  defp decode_data_params(_, _), do: %{}

  # Decode a single indexed topic value based on its ABI type
  defp decode_topic_value(_type, nil), do: nil

  defp decode_topic_value("address", "0x" <> hex) when byte_size(hex) == 64 do
    # Address is in the last 40 chars of the 32-byte topic
    "0x" <> String.slice(hex, 24, 40)
  end

  defp decode_topic_value("address", value), do: value

  defp decode_topic_value(type, "0x" <> hex) when type in ["uint256", "uint128", "uint64", "uint32", "uint16", "uint8"] do
    {val, _} = Integer.parse(hex, 16)
    val
  end

  defp decode_topic_value(type, "0x" <> hex) when type in ["int256", "int128", "int64", "int32", "int16", "int8"] do
    {val, _} = Integer.parse(hex, 16)
    bits = 256

    if val >= :math.pow(2, bits - 1) |> trunc() do
      val - (:math.pow(2, bits) |> trunc())
    else
      val
    end
  end

  defp decode_topic_value("bool", "0x" <> hex) do
    {val, _} = Integer.parse(hex, 16)
    val != 0
  end

  defp decode_topic_value(_type, value), do: value

  # Decode a non-indexed data value
  defp decode_data_value("address", hex) when byte_size(hex) == 64 do
    "0x" <> String.slice(hex, 24, 40)
  end

  defp decode_data_value(type, hex) when type in ["uint256", "uint128", "uint64", "uint32", "uint16", "uint8"] do
    case Integer.parse(hex, 16) do
      {val, _} -> val
      :error -> "0x" <> hex
    end
  end

  defp decode_data_value("bool", hex) do
    case Integer.parse(hex, 16) do
      {val, _} -> val != 0
      :error -> false
    end
  end

  defp decode_data_value(_type, hex), do: "0x" <> hex

  # Split a hex string into chunks of a given size
  defp chunk_hex(hex, size) do
    hex
    |> String.graphemes()
    |> Enum.chunk_every(size)
    |> Enum.map(&Enum.join/1)
  end
end
