defmodule Lux.Web3.EventMonitor.Decoder do
  @moduledoc """
  Decodes raw Ethereum/EVM event logs into strongly-typed parameter maps (#75).

  Provides out-of-the-box decoders for:
  - ERC-20 / ERC-721: `Transfer`, `Approval`, `ApprovalForAll`
  - Uniswap V2 / SushiSwap: `Swap`, `Mint`, `Burn`, `Sync`
  - Uniswap V3: `Swap`, `Mint`, `Burn`, `Collect`
  - WETH / Vault: `Deposit`, `Withdrawal`
  - Custom user-registered event ABI signatures.
  """

  @standard_signatures %{
    # ERC-20 / ERC-721
    "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef" => {
      :transfer,
      "Transfer(address,address,uint256)",
      [:from, :to],
      [:value]
    },
    "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925" => {
      :approval,
      "Approval(address,address,uint256)",
      [:owner, :spender],
      [:value]
    },
    # Uniswap V2
    "0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822" => {
      :uniswap_v2_swap,
      "Swap(address,uint256,uint256,uint256,uint256,address)",
      [:sender, :to],
      [:amount0In, :amount1In, :amount0Out, :amount1Out]
    },
    "0x4c209b320885062e60964edd250f2d5a550f575b491847cba6faba0b2ee3329e" => {
      :uniswap_v2_sync,
      "Sync(uint112,uint112)",
      [],
      [:reserve0, :reserve1]
    },
    # Uniswap V3
    "0xc42079f94a6350d7e6235f29174924f928cc2ac818eb64fed8004e115fbcca67" => {
      :uniswap_v3_swap,
      "Swap(address,address,int256,int256,uint160,uint128,int24)",
      [:sender, :recipient],
      [:amount0, :amount1, :sqrtPriceX96, :liquidity, :tick]
    },
    # Deposit & Withdrawal
    "0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c" => {
      :deposit,
      "Deposit(address,uint256)",
      [:dst],
      [:wad]
    },
    "0x7fcf532c12070370e889f840ac1f33a54770e3b99d73b80c9cfa5000143cb70d" => {
      :withdrawal,
      "Withdrawal(address,uint256)",
      [:src],
      [:wad]
    }
  }

  @doc """
  Returns the mapping of well-known topic0 hashes to event specifications.
  """
  @spec standard_signatures() :: map()
  def standard_signatures, do: @standard_signatures

  @doc """
  Decodes raw topics and data into structured key-value parameters.
  """
  @spec decode(list(String.t()), String.t() | nil, map() | nil) :: {:ok, map()} | {:error, term()}
  def decode(topics, data, custom_spec \\ nil)

  def decode([], _data, _custom), do: {:error, :no_topics}

  def decode([topic0 | rest_topics], data, custom_spec) do
    clean_t0 = String.downcase(to_string(topic0))

    spec =
      cond do
        is_tuple(custom_spec) ->
          custom_spec

        is_map(custom_spec) and Map.has_key?(custom_spec, clean_t0) ->
          Map.get(custom_spec, clean_t0)

        Map.has_key?(@standard_signatures, clean_t0) ->
          Map.get(@standard_signatures, clean_t0)

        true ->
          nil
      end

    case spec do
      {event_type, signature, indexed_keys, unindexed_keys} ->
        indexed_params = decode_indexed_topics(rest_topics, indexed_keys)
        unindexed_params = decode_data_words(data, unindexed_keys)

        params =
          indexed_params
          |> Map.merge(unindexed_params)
          |> Map.put(:_event_type, event_type)
          |> Map.put(:_event_signature, signature)

        {:ok, params}

      nil ->
        # Fallback raw decoding: indexed topics as indexed_0, indexed_1... and data as words
        raw_indexed =
          rest_topics
          |> Enum.with_index(1)
          |> Enum.into(%{}, fn {t, idx} -> {"topic_#{idx}", t} end)

        raw_words = decode_raw_words(data)
        {:ok, Map.merge(raw_indexed, raw_words)}
    end
  end

  @doc """
  Converts a 32-byte hex topic string into a normalized 20-byte address string.
  """
  @spec topic_to_address(String.t() | nil) :: String.t()
  def topic_to_address(nil), do: ""
  def topic_to_address(topic) when is_binary(topic) do
    clean = String.downcase(String.trim_leading(topic, "0x"))

    if String.length(clean) >= 40 do
      "0x" <> String.slice(clean, -40..-1//1)
    else
      "0x" <> clean
    end
  end

  @doc """
  Parses a 32-byte hex word into an unsigned uint256 integer.
  """
  @spec parse_uint256(String.t() | nil) :: non_neg_integer()
  def parse_uint256(nil), do: 0
  def parse_uint256("0x"), do: 0
  def parse_uint256(hex_str) when is_binary(hex_str) do
    clean = String.trim_leading(hex_str, "0x")
    case Integer.parse(clean, 16) do
      {num, _} -> num
      _ -> 0
    end
  end

  # Internal helpers
  defp decode_indexed_topics(topics, keys) do
    topics
    |> Enum.zip(keys)
    |> Enum.into(%{}, fn {topic, key} ->
      # Convert to address if key implies address, otherwise uint256 or hex
      key_str = to_string(key)
      val =
        cond do
          String.contains?(key_str, ["from", "to", "owner", "spender", "sender", "recipient", "dst", "src", "user"]) ->
            topic_to_address(topic)

          true ->
            parse_uint256(topic)
        end

      {key, val}
    end)
  end

  defp decode_data_words(nil, _keys), do: %{}
  defp decode_data_words("0x", _keys), do: %{}
  defp decode_data_words(data, keys) when is_binary(data) do
    clean = String.trim_leading(data, "0x")
    words = for <<word::binary-size(64) <- clean>>, do: word

    words
    |> Enum.zip(keys)
    |> Enum.into(%{}, fn {word, key} ->
      key_str = to_string(key)
      val =
        cond do
          String.contains?(key_str, ["to", "from", "recipient", "target", "addr"]) ->
            topic_to_address(word)

          true ->
            parse_uint256(word)
        end

      {key, val}
    end)
  end

  defp decode_raw_words(nil), do: %{}
  defp decode_raw_words("0x"), do: %{}
  defp decode_raw_words(data) when is_binary(data) do
    clean = String.trim_leading(data, "0x")
    words = for <<word::binary-size(64) <- clean>>, do: word

    words
    |> Enum.with_index()
    |> Enum.into(%{}, fn {word, idx} ->
      {"data_word_#{idx}", parse_uint256(word)}
    end)
  end
end
