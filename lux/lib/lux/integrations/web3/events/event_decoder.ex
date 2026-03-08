defmodule Lux.Integrations.Web3.Events.EventDecoder do
  @moduledoc """
  Decodes raw EVM event logs into structured data.

  Supports common ERC-20/721/1155 events and custom ABI event signatures.
  """

  # Common event signatures (keccak256 of event signature)
  @known_events %{
    "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef" => :transfer,
    "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925" => :approval,
    "0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c" => :deposit,
    "0x7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b65" => :withdrawal,
    "0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822" => :swap,
    "0x1c411e9a96e071241c2f21f7726b17ae89e3cab4c78be50e062b03a9fffbbad1" => :sync,
    "0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62" => :transfer_single,
    "0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb" => :transfer_batch
  }

  @doc "Decode a raw log into a structured event."
  def decode(log) do
    topics = log[:topics] || log["topics"] || []
    data = log[:data] || log["data"] || "0x"

    event_sig = List.first(topics)
    event_type = Map.get(@known_events, event_sig, :unknown)

    base = %{
      type: event_type,
      signature: event_sig,
      address: log[:address] || log["address"],
      block_number: log[:block_number] || log["blockNumber"],
      transaction_hash: log[:transaction_hash] || log["transactionHash"],
      log_index: log[:log_index] || log["logIndex"]
    }

    decoded_params = decode_params(event_type, topics, data)
    Map.merge(base, decoded_params)
  end

  @doc "List known event types."
  def known_events, do: @known_events

  @doc "Get event signature hash for a given signature string."
  def event_topic(signature) when is_binary(signature) do
    "0x" <> Base.encode16(:crypto.hash(:sha3_256, signature), case: :lower)
  end

  defp decode_params(:transfer, topics, data) do
    from = decode_address(Enum.at(topics, 1))
    to = decode_address(Enum.at(topics, 2))

    # ERC-20: value in data; ERC-721: tokenId in topic[3]
    case {Enum.at(topics, 3), data} do
      {nil, hex_data} ->
        %{from: from, to: to, value: decode_uint256(hex_data)}

      {token_id_hex, _} ->
        %{from: from, to: to, token_id: decode_uint256(token_id_hex)}
    end
  end

  defp decode_params(:approval, topics, data) do
    %{
      owner: decode_address(Enum.at(topics, 1)),
      spender: decode_address(Enum.at(topics, 2)),
      value: decode_uint256(data)
    }
  end

  defp decode_params(:swap, topics, data) do
    %{
      sender: decode_address(Enum.at(topics, 1)),
      to: decode_address(Enum.at(topics, 2)),
      data: data
    }
  end

  defp decode_params(:deposit, topics, data) do
    %{dst: decode_address(Enum.at(topics, 1)), value: decode_uint256(data)}
  end

  defp decode_params(:withdrawal, topics, data) do
    %{src: decode_address(Enum.at(topics, 1)), value: decode_uint256(data)}
  end

  defp decode_params(_type, _topics, data) do
    %{raw_data: data}
  end

  defp decode_address(nil), do: nil
  defp decode_address("0x" <> hex) when byte_size(hex) >= 40 do
    "0x" <> String.slice(hex, -40, 40)
  end
  defp decode_address(other), do: other

  defp decode_uint256(nil), do: 0
  defp decode_uint256("0x"), do: 0
  defp decode_uint256("0x" <> hex) do
    case Integer.parse(hex, 16) do
      {n, _} -> n
      :error -> 0
    end
  end
  defp decode_uint256(_), do: 0
end
