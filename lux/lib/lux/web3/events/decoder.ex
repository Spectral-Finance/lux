defmodule Lux.Web3.Events.Decoder do
  @moduledoc """
  Decodes smart contract event data using ABI definitions.

  Supports both Etherscan-sourced ABIs and manually provided ABI
  fragments. Handles indexed (topics) and non-indexed (data) parameters.
  """

  @doc """
  Computes the keccak256 hash of an event signature string to get topic0.
  Example: keccak256("Transfer(address,address,uint256)")
  """
  @spec event_signature_to_topic(String.t()) :: String.t()
  def event_signature_to_topic(signature) do
    signature
    |> :binary.encode_utf8()
    |> :crypto.hash(:keccak_256)
    |> Base.encode16(case: :lower)
    |> then(fn hash -> "0x#{hash}" end)
  end

  @doc """
  Decodes event log data using an ABI entry.

  ## Parameters

  - `log`: An `Lux.Web3.Events.Event` struct
  - `abi_entry`: A single ABI function/event map with `inputs` array

  ## Returns

  A map of parameter names to decoded values.
  """
  @spec decode_event(event :: Lux.Web3.Events.Event.t(), abi_entry :: map()) :: map()
  def decode_event(event, abi_entry) do
    inputs = abi_entry["inputs"] || []

    indexed_params =
      inputs
      |> Enum.filter(&(&1["indexed"] == true))
      |> Enum.with_index(fn input, i ->
        # Find the topic position: skip non-indexed inputs before this one
        topic_idx = topic_index(inputs, i)
        topic_value = Enum.at(event.topics, topic_idx, "")
        {input["name"], input["type"], topic_value}
      end)
      |> Enum.map(fn {name, type, value} ->
        {name, decode_log_param(type, value)}
      end)
      |> Map.new()

    non_indexed_params =
      inputs
      |> Enum.reject(&(&1["indexed"] == true))
      |> then(fn params ->
        case decode_calldata(event.data, params) do
          {:ok, decoded} -> decoded
          :error -> %{}
        end
      end)

    Map.merge(non_indexed_params, indexed_params)
  end

  @doc """
  Finds the topic index for a given input position, accounting for
  non-indexed inputs that don't consume topics.
  """
  @spec topic_index([map()], pos_integer()) :: non_neg_integer()
  def topic_index(inputs, position) do
    inputs
    |> Enum.take(position)
    |> Enum.count(&(&1["indexed"] == true))
  end

  @doc """
  Decodes a single parameter from a log topic value.
  """
  @spec decode_log_param(String.t(), String.t()) :: any()
  def decode_log_param("address", value) do
    value
    |> String.trim_leading("0x")
    |> String.pad_leading(40, "0")
    |> then(fn hex -> "0x#{hex}" end)
  end

  def decode_log_param("bool", value) do
    value == "0x0000000000000000000000000000000000000000000000000000000000000000" ||
      value == "0x0" || value == "0"
  end

  def decode_log_param("bytes32", value) do
    value
    |> String.trim_leading("0x")
    |> String.pad_trailing(64, "0")
  end

  def decode_log_param(type, value) when type in ["uint256", "uint128", "uint64", "uint256", "int256", "int128", "int64"] do
    Lux.Web3.Events.Event.parse_hex_or_dec(value)
  end

  def decode_log_param("bytes", value) do
    value
  end

  def decode_log_param("string", value) do
    value
  end

  def decode_log_param(_type, value) do
    value
  end

  @doc """
  Decodes non-indexed parameters from the event data field.
  """
  @spec decode_calldata(String.t(), [map()]) :: {:ok, map()} | :error
  def decode_calldata("", _inputs), do: {:ok, %{}}

  def decode_calldata(data, inputs) when is_list(inputs) and length(inputs) > 0 do
    hex_data = String.trim_leading(data, "0x")

    if String.length(hex_data) < 64 do
      {:ok, %{}}
    else
      decoded =
        inputs
        |> Enum.reduce({hex_data, %{}} fn input, {remaining, acc} ->
          bit_size = param_bit_size(input["type"])
          hex_chars = div(bit_size, 4)
          chunk = String.slice(remaining, 0, min(hex_chars, String.length(remaining)))
          remaining = String.slice(remaining, hex_chars, String.length(remaining))

          value =
            case chunk do
              "" -> ""
              _ -> "0x#{chunk}" |> decode_log_param(input["type"])
            end

          {remaining, Map.put(acc, input["name"], value)}
        end)
        |> elem(1)

      {:ok, decoded}
    end
  end

  def decode_calldata(_data, _inputs), do: {:ok, %{}}

  @doc """
  Returns the bit size for a Solidity type.
  """
  @spec param_bit_size(String.t()) :: non_neg_integer()
  def param_bit_size(type) do
    case type do
      "uint256" -> 256
      "uint128" -> 128
      "uint64" -> 64
      "uint32" -> 32
      "uint16" -> 16
      "uint8" -> 8
      "int256" -> 256
      "int128" -> 128
      "int64" -> 64
      "int32" -> 32
      "address" -> 160
      "bool" -> 8
      "bytes32" -> 256
      "bytes" -> 256
      "string" -> 256
      _ -> 256
    end
  end

  @doc """
  Extracts the event ABI entry from a full contract ABI by signature.
  """
  @spec find_abi_entry([map()], String.t()) :: map() | nil
  def find_abi_entry(abi, event_signature) do
    topic0 = event_signature_to_topic(event_signature)

    abi
    |> Enum.find(fn entry ->
      entry["type"] == "event" and
        entry["name"] != nil and
        event_name_with_params(entry) == event_signature
    end)
  end

  defp event_name_with_params(entry) do
    params =
      (entry["inputs"] || [])
      |> Enum.map(& &1["type"])
      |> Enum.join(",")

    "#{entry["name"]}(#{params})"
  end

  @doc """
  Parses a contract ABI JSON string and returns event entries.
  """
  @spec parse_abi_events(String.t()) :: [map()]
  def parse_abi_events(abi_json) do
    case Jason.decode(abi_json) do
      {:ok, abi} when is_list(abi) ->
        abi
        |> Enum.filter(&(&1["type"] == "event"))
        |> Enum.map(fn entry ->
          params = (entry["inputs"] || []) |> Enum.map(& &1["type"]) |> Enum.join(",")
          Map.put(entry, :signature, "#{entry["name"]}(#{params})")
        end)

      _ ->
        []
    end
  end
end
