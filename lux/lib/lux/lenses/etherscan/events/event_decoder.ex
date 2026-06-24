defmodule Lux.Lenses.Etherscan.Events.EventDecoder do
  @moduledoc """
  Decodes smart contract event logs using ABI information.
  """

  @doc """
  Looks up an event definition from the ABI by its signature hash.
  """
  @spec find_event_by_signature(list(map()), String.t()) :: {:ok, map()} | :error
  def find_event_by_signature(abi, signature) when is_list(abi) and is_binary(signature) do
    abi
    |> Enum.find(fn entry ->
      case entry do
        %{"type" => "event", "name" => name, "inputs" => inputs} ->
          sig = compute_event_signature(name, inputs)
          sig == signature
        _ -> false
      end
    end)
    |> case do
      nil -> :error
      event -> {:ok, event}
    end
  end

  def find_event_by_signature(_, _), do: :error

  @doc """
  Decodes a raw event log into structured data using the provided ABI.
  """
  @spec decode_event(list(map()), String.t(), list(String.t()), String.t()) ::
          {:ok, map()} | {:error, String.t()}
  def decode_event(abi, signature, topics, data)
      when is_list(abi) and is_binary(signature) and is_list(topics) and is_binary(data) do
    case find_event_by_signature(abi, signature) do
      {:ok, event_def} ->
        {:ok, build_decoded_event(event_def, topics, data, signature)}
      :error ->
        {:error, "Event signature #{signature} not found in ABI"}
    end
  end

  def decode_event(_, _, _, _), do: {:error, "Invalid parameters for event decoding"}

  @doc """
  Decodes a list of raw log entries using the provided ABI.
  """
  @spec decode_events(list(map()), list(map())) :: list(map())
  def decode_events(logs, abi) when is_list(logs) and is_list(abi) do
    Enum.map(logs, fn log ->
      case log["topics"] do
        [sig | _] ->
          case decode_event(abi, sig, log["topics"], log["data"]) do
            {:ok, decoded} ->
              Map.put(log, "decoded", Map.put(decoded, "raw_log", log))
            {:error, _} ->
              Map.put(log, "decoded", %{"raw" => true, "signature" => sig})
          end
        [] ->
          Map.put(log, "decoded", %{"raw" => true, "signature" => ""})
      end
    end)
  end

  def decode_events(_, _), do: []

  @doc """
  Computes the Keccak-256 hash of an event signature string.
  """
  @spec compute_event_signature(String.t(), list(map())) :: String.t()
  def compute_event_signature(name, inputs) when is_binary(name) and is_list(inputs) do
    params = Enum.map(inputs, &Map.get(&1, "type", "")) |> Enum.join(",")
    compute_event_signature("#{name}(#{params})")
  end
  def compute_event_signature(signature_string) when is_binary(signature_string) do
    ExKeccak.Hash.keccak(signature_string, 256)
    |> Base.encode16(case: :lower)
    |> then(&"0x#{&1}")
  end

  def compute_event_signature(_), do: ""

  defp build_decoded_event(event_def, topics, data, signature) do
    inputs = event_def["inputs"] || []

    indexed =
      inputs
      |> Enum.filter(fn i -> Map.get(i, "indexed", false) end)
      |> Enum.zip(Enum.slice(topics, 1..-1//1))
      |> Enum.map(fn {input, topic} ->
        %{name: Map.get(input, "name", ""), type: Map.get(input, "type", ""), value: topic}
      end)

    non_indexed =
      inputs
      |> Enum.reject(fn i -> Map.get(i, "indexed", false) end)
      |> Enum.map(fn input ->
        %{name: Map.get(input, "name", ""), type: Map.get(input, "type", ""), value: Map.get(data, "data", "")}
      end)

    %{
      name: event_def["name"],
      signature: signature,
      indexed: indexed,
      non_indexed: non_indexed,
      anonymous?: Map.get(event_def, "anonymous", false)
    }
  end
end
