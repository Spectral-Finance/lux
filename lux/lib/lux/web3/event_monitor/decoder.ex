defmodule Lux.Web3.EventMonitor.Decoder do
  @moduledoc """
  Smart contract event ABI registry and log decoder.

  Supports built-in standard EVM events (`Transfer`, `Approval`, `Swap`, `Sync`,
  `OwnershipTransferred`) as well as custom runtime ABI event definitions with
  indexed topic and non-indexed data word decoding.
  """

  @abi_table :lux_web3_event_abis

  defmodule EventABI do
    @moduledoc """
    Specification for a smart contract event ABI used to decode raw logs.
    """

    @type input_param :: %{
            name: atom() | String.t(),
            type: :address | :uint256 | :int256 | :bool | :bytes32 | :string,
            indexed: boolean()
          }

    @type t :: %__MODULE__{
            name: String.t(),
            signature: String.t(),
            topic0: String.t(),
            inputs: [input_param()]
          }

    defstruct name: "",
              signature: "",
              topic0: "",
              inputs: []
  end

  defmodule DecodedEvent do
    @moduledoc """
    Canonical decoded smart contract event log.
    """

    @type t :: %__MODULE__{
            id: String.t(),
            chain: atom(),
            contract_address: String.t(),
            block_number: non_neg_integer(),
            tx_hash: String.t() | nil,
            log_index: non_neg_integer(),
            event_name: String.t(),
            signature: String.t() | nil,
            topic0: String.t() | nil,
            topics: [String.t()],
            data: String.t(),
            params: map(),
            timestamp: non_neg_integer()
          }

    defstruct id: nil,
              chain: :ethereum,
              contract_address: nil,
              block_number: 0,
              tx_hash: nil,
              log_index: 0,
              event_name: "UnknownEvent",
              signature: nil,
              topic0: nil,
              topics: [],
              data: "0x",
              params: %{},
              timestamp: 0
  end

  @doc """
  Ensures the ABI registry ETS table is initialized with standard EVM events.
  """
  @spec ensure_started() :: :ok
  def ensure_started do
    case :ets.whereis(@abi_table) do
      :undefined ->
        try do
          :ets.new(@abi_table, [:named_table, :public, :set, read_concurrency: true])
          seed_defaults()
        rescue
          ArgumentError -> :ok
        end

      _tid ->
        :ok
    end
  end

  @doc """
  Resets the ABI registry to built-in standard event definitions.
  """
  @spec reset!() :: :ok
  def reset! do
    ensure_started()
    :ets.delete_all_objects(@abi_table)
    seed_defaults()
  end

  @doc """
  Computes the `0x`-prefixed Keccak-256 `topic0` hash for a canonical event signature
  (e.g. `"Transfer(address,address,uint256)"`).
  """
  @spec compute_topic0(String.t()) :: String.t()
  def compute_topic0(signature) when is_binary(signature) do
    digest =
      if Code.ensure_loaded?(ExKeccak) do
        ExKeccak.hash_256(signature)
      else
        :crypto.hash(:sha3_256, signature)
      end

    "0x" <> Base.encode16(digest, case: :lower)
  end

  @doc """
  Registers a custom event ABI definition for automatic decoding.
  """
  @spec register_abi(EventABI.t() | map()) :: {:ok, EventABI.t()}
  def register_abi(%EventABI{} = abi) do
    ensure_started()

    topic0 =
      if is_binary(abi.topic0) and String.starts_with?(abi.topic0, "0x") and
           byte_size(abi.topic0) == 66 do
        String.downcase(abi.topic0)
      else
        compute_topic0(abi.signature)
      end

    normalized = %{abi | topic0: topic0}
    :ets.insert(@abi_table, {topic0, normalized})
    {:ok, normalized}
  end

  def register_abi(attrs) when is_map(attrs) do
    abi = struct(EventABI, attrs)
    register_abi(abi)
  end

  @doc """
  Looks up a registered `%EventABI{}` by `topic0` or event name.
  """
  @spec lookup_abi(String.t()) :: {:ok, EventABI.t()} | {:error, :not_found}
  def lookup_abi("0x" <> _ = topic0) do
    ensure_started()
    key = String.downcase(topic0)

    case :ets.lookup(@abi_table, key) do
      [{^key, abi}] -> {:ok, abi}
      [] -> {:error, :not_found}
    end
  end

  def lookup_abi(event_name) when is_binary(event_name) do
    ensure_started()

    @abi_table
    |> :ets.tab2list()
    |> Enum.find_value({:error, :not_found}, fn {_topic0, abi} ->
      if abi.name == event_name, do: {:ok, abi}
    end)
  end

  @doc """
  Decodes a raw JSON-RPC log map into a `%DecodedEvent{}` struct using registered
  or inline event ABI definitions.
  """
  @spec decode_log(atom(), map(), [EventABI.t() | map()]) :: DecodedEvent.t()
  def decode_log(chain, raw_log, custom_abis \\ []) when is_map(raw_log) do
    ensure_started()
    topics = Enum.map(raw_log["topics"] || [], &downcase_str/1)
    topic0 = List.first(topics)
    block_number = hex_to_int(raw_log["blockNumber"])
    log_index = hex_to_int(raw_log["logIndex"])
    tx_hash = downcase_str(raw_log["transactionHash"])
    contract = downcase_str(raw_log["address"])
    data = raw_log["data"] || "0x"

    abi = resolve_abi(topic0, custom_abis)

    {event_name, signature, params} =
      case abi do
        %EventABI{} = found ->
          {found.name, found.signature, decode_inputs(found.inputs, Enum.drop(topics, 1), data)}

        nil ->
          {"UnknownEvent", nil, %{"raw_data" => data}}
      end

    %DecodedEvent{
      id: "#{chain}:#{block_number}:#{tx_hash}:#{log_index}",
      chain: chain,
      contract_address: contract,
      block_number: block_number,
      tx_hash: tx_hash,
      log_index: log_index,
      event_name: event_name,
      signature: signature,
      topic0: topic0,
      topics: topics,
      data: data,
      params: params,
      timestamp: hex_to_int(raw_log["timestamp"] || System.system_time(:second))
    }
  end

  @doc """
  Converts a hex string or integer to a non-negative integer.
  """
  @spec hex_to_int(term()) :: non_neg_integer()
  def hex_to_int(val) when is_integer(val) and val >= 0, do: val

  def hex_to_int("0x" <> hex) when byte_size(hex) > 0 do
    case Integer.parse(hex, 16) do
      {num, ""} when num >= 0 -> num
      _ -> 0
    end
  end

  def hex_to_int(_), do: 0

  defp resolve_abi(nil, _custom_abis), do: nil

  defp resolve_abi(topic0, custom_abis) do
    inline =
      Enum.find_value(custom_abis, fn
        %EventABI{} = abi ->
          normalized_t0 =
            if abi.topic0 != "",
              do: String.downcase(abi.topic0),
              else: compute_topic0(abi.signature)

          if normalized_t0 == topic0, do: %{abi | topic0: normalized_t0}

        map when is_map(map) ->
          abi = struct(EventABI, map)
          normalized_t0 =
            if abi.topic0 != "",
              do: String.downcase(abi.topic0),
              else: compute_topic0(abi.signature)

          if normalized_t0 == topic0, do: %{abi | topic0: normalized_t0}
      end)

    cond do
      not is_nil(inline) ->
        inline

      match?({:ok, _}, lookup_abi(topic0)) ->
        {:ok, abi} = lookup_abi(topic0)
        abi

      true ->
        nil
    end
  end

  defp decode_inputs(inputs, indexed_topics, data) do
    data_words = split_data_words(data)

    {params, _rem_topics, _rem_words} =
      Enum.reduce(inputs, {%{}, indexed_topics, data_words}, fn input,
                                                                 {acc, topics_acc, words_acc} ->
        if Map.get(input, :indexed, false) do
          [raw_word | rest_topics] = topics_acc ++ ["0x0"]
          decoded = decode_word(input.type, raw_word)
          {Map.put(acc, input.name, decoded), rest_topics, words_acc}
        else
          [raw_word | rest_words] = words_acc ++ ["0x0"]
          decoded = decode_word(input.type, raw_word)
          {Map.put(acc, input.name, decoded), topics_acc, rest_words}
        end
      end)

    params
  end

  defp split_data_words("0x" <> hex) when byte_size(hex) >= 64 do
    hex
    |> String.codepoints()
    |> Enum.chunk_every(64)
    |> Enum.map(&("0x" <> Enum.join(&1)))
  end

  defp split_data_words("0x" <> hex) when byte_size(hex) > 0 do
    ["0x" <> String.pad_leading(hex, 64, "0")]
  end

  defp split_data_words(_), do: []

  defp decode_word(:address, "0x" <> hex) when byte_size(hex) == 64 do
    "0x" <> String.downcase(String.slice(hex, 24, 40))
  end

  defp decode_word(:address, "0x" <> hex) do
    "0x" <> String.downcase(String.pad_leading(hex, 40, "0"))
  end

  defp decode_word(:uint256, word), do: hex_to_int(word)

  defp decode_word(:int256, word) do
    unsigned = hex_to_int(word)
    max_int256 = Bitwise.bsl(1, 255)
    full_256 = Bitwise.bsl(1, 256)
    if unsigned >= max_int256, do: unsigned - full_256, else: unsigned
  end

  defp decode_word(:bool, word), do: hex_to_int(word) != 0
  defp decode_word(:bytes32, word), do: downcase_str(word)
  defp decode_word(_type, word), do: word

  defp seed_defaults do
    Enum.each(default_abis(), fn abi ->
      :ets.insert(@abi_table, {abi.topic0, abi})
    end)

    :ok
  end

  defp default_abis do
    [
      %EventABI{
        name: "Transfer",
        signature: "Transfer(address,address,uint256)",
        topic0: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
        inputs: [
          %{name: :from, type: :address, indexed: true},
          %{name: :to, type: :address, indexed: true},
          %{name: :value, type: :uint256, indexed: false}
        ]
      },
      %EventABI{
        name: "Approval",
        signature: "Approval(address,address,uint256)",
        topic0: "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925",
        inputs: [
          %{name: :owner, type: :address, indexed: true},
          %{name: :spender, type: :address, indexed: true},
          %{name: :value, type: :uint256, indexed: false}
        ]
      },
      %EventABI{
        name: "Swap",
        signature: "Swap(address,uint256,uint256,uint256,uint256,address)",
        topic0: "0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822",
        inputs: [
          %{name: :sender, type: :address, indexed: true},
          %{name: :amount0_in, type: :uint256, indexed: false},
          %{name: :amount1_in, type: :uint256, indexed: false},
          %{name: :amount0_out, type: :uint256, indexed: false},
          %{name: :amount1_out, type: :uint256, indexed: false},
          %{name: :to, type: :address, indexed: true}
        ]
      },
      %EventABI{
        name: "OwnershipTransferred",
        signature: "OwnershipTransferred(address,address)",
        topic0: "0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0",
        inputs: [
          %{name: :previous_owner, type: :address, indexed: true},
          %{name: :new_owner, type: :address, indexed: true}
        ]
      }
    ]
  end

  defp downcase_str(nil), do: nil
  defp downcase_str(val) when is_binary(val), do: String.downcase(val)
end
