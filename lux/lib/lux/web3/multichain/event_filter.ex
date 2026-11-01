defmodule Lux.Web3.Multichain.EventFilter do
  @moduledoc """
  Event filtering, signature matching, and decoding utility for multi-chain EVM events (#74).

  Provides topic hashes for standard DeFi and token contracts:
  - ERC-20 & ERC-721 Transfer & Approval
  - Uniswap / Pancake / Sushi Swap (V2 & V3)
  """

  alias Lux.Web3.Multichain.Schemas.{Event, TokenTransfer}

  @topics %{
    erc20_transfer: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
    erc20_approval: "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925",
    uniswap_v2_swap: "0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822",
    uniswap_v3_swap: "0xc42079f94a6350d7e6235f29174924f928cc2ac818eb64fed8004e115fbcca67"
  }

  @doc """
  Retrieves known topic0 hash by event identifier atom.
  """
  @spec get_known_topic(atom()) :: String.t() | nil
  def get_known_topic(key) when is_atom(key), do: Map.get(@topics, key)

  @doc """
  Determines if an Event matches the specified filter criteria.
  Criteria can include:
  - `:contract_address`: Contract emitting the event (case-insensitive)
  - `:topic0` or `:event_type`: Topic0 hash or known topic atom
  - `:from_address` / `:to_address`: Match indexed parameters
  - `:chain`: Specific chain atom
  """
  @spec matches?(Event.t(), map()) :: boolean()
  def matches?(%Event{} = event, filter) when is_map(filter) do
    Enum.all?(filter, fn
      {:chain, chain} ->
        event.chain == chain

      {:contract_address, addr} ->
        String.downcase(to_string(addr)) == event.contract_address

      {:topic0, topic} ->
        case event.topics do
          [t0 | _] -> String.downcase(to_string(topic)) == t0
          _ -> false
        end

      {:event_type, type} when is_atom(type) ->
        case Map.get(@topics, type) do
          nil -> false
          expected_topic ->
            case event.topics do
              [t0 | _] -> t0 == expected_topic
              _ -> false
            end
        end

      {:from_address, from_addr} ->
        expected = normalize_address(from_addr)
        case event.decoded_params do
          %{"from" => f} -> normalize_address(f) == expected
          %{from: f} -> normalize_address(f) == expected
          _ ->
            case event.topics do
              [_, t1 | _] -> topic_to_address(t1) == expected
              _ -> false
            end
        end

      {:to_address, to_addr} ->
        expected = normalize_address(to_addr)
        case event.decoded_params do
          %{"to" => t} -> normalize_address(t) == expected
          %{to: t} -> normalize_address(t) == expected
          _ ->
            case event.topics do
              [_, _, t2 | _] -> topic_to_address(t2) == expected
              _ -> false
            end
        end

      _other ->
        true
    end)
  end

  @doc """
  Parses an ERC-20 or ERC-721 Transfer event into a `%TokenTransfer{}` struct.
  """
  @spec parse_token_transfer(Event.t()) :: {:ok, TokenTransfer.t()} | {:error, term()}
  def parse_token_transfer(%Event{topics: [t0, t1, t2 | _]} = event) do
    if t0 == @topics[:erc20_transfer] do
      from = topic_to_address(t1)
      to = topic_to_address(t2)
      amount = parse_hex_uint(event.data)

      {:ok,
       %TokenTransfer{
         chain_id: event.chain_id,
         chain: event.chain,
         token_address: event.contract_address,
         token_standard: :erc20,
         from: from,
         to: to,
         amount: amount,
         token_id: nil,
         block_number: event.block_number,
         tx_hash: event.tx_hash
       }}
    else
      {:error, :not_a_transfer_event}
    end
  end

  def parse_token_transfer(_event), do: {:error, :insufficient_topics}

  @doc """
  Converts a 32-byte hex topic string into a normalized 20-byte Ethereum address.
  """
  @spec topic_to_address(String.t()) :: String.t()
  def topic_to_address(topic) when is_binary(topic) do
    clean = String.downcase(String.trim_leading(topic, "0x"))

    if String.length(clean) >= 40 do
      "0x" <> String.slice(clean, -40..-1//1)
    else
      "0x" <> clean
    end
  end

  def topic_to_address(_), do: ""

  @doc """
  Parses a hex uint256 string into an integer.
  """
  @spec parse_hex_uint(String.t() | nil) :: non_neg_integer()
  def parse_hex_uint(nil), do: 0
  def parse_hex_uint("0x"), do: 0

  def parse_hex_uint(data) when is_binary(data) do
    clean = String.trim_leading(data, "0x")
    case Integer.parse(clean, 16) do
      {val, _} -> val
      _ -> 0
    end
  end

  defp normalize_address(addr) when is_binary(addr) do
    String.downcase(to_string(addr))
  end

  defp normalize_address(_), do: ""
end
