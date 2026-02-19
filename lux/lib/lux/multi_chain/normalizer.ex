defmodule Lux.MultiChain.Normalizer do
  @moduledoc """
  Data normalization utilities for converting raw blockchain API responses
  into unified `Lux.MultiChain.DataModel` structs.

  Handles differences across chain APIs (Etherscan v2, RPC responses) and
  provides consistent data representation regardless of source chain.

  ## Features

  - Hex string to integer conversion
  - Wei to Ether (and other native currency) conversion
  - Timestamp normalization to DateTime
  - Transaction status mapping
  - Gas price unit conversion
  """

  alias Lux.MultiChain.DataModel.{Block, Event, GasPrice, TokenBalance, Transaction}

  @doc """
  Normalizes a raw Etherscan-style block response into a Block struct.

  ## Parameters

  - `raw` - Map with string keys from API response
  - `chain` - Chain atom identifier
  - `chain_id` - Numeric chain ID
  """
  @spec normalize_block(map(), atom(), pos_integer()) :: Block.t()
  def normalize_block(raw, chain, chain_id) do
    %Block{
      chain: chain,
      chain_id: chain_id,
      number: parse_integer(raw["blockNumber"] || raw["number"]),
      hash: raw["blockHash"] || raw["hash"],
      parent_hash: raw["parentHash"],
      timestamp: parse_timestamp(raw["timeStamp"] || raw["timestamp"]),
      miner: raw["blockMiner"] || raw["miner"],
      gas_used: parse_integer(raw["gasUsed"]),
      gas_limit: parse_integer(raw["gasLimit"]),
      base_fee_per_gas: parse_integer_or_nil(raw["baseFeePerGas"]),
      transaction_count: parse_integer(raw["txCount"] || raw["transactionCount"] || "0"),
      size: parse_integer_or_nil(raw["blockSize"] || raw["size"])
    }
  end

  @doc """
  Normalizes a raw transaction response into a Transaction struct.

  ## Parameters

  - `raw` - Map with string keys from API response
  - `chain` - Chain atom identifier
  - `chain_id` - Numeric chain ID
  """
  @spec normalize_transaction(map(), atom(), pos_integer()) :: Transaction.t()
  def normalize_transaction(raw, chain, chain_id) do
    value_wei = raw["value"] || "0"
    decimals = chain_decimals(chain)

    %Transaction{
      chain: chain,
      chain_id: chain_id,
      hash: raw["hash"],
      block_number: parse_integer(raw["blockNumber"]),
      block_hash: raw["blockHash"],
      from: String.downcase(raw["from"] || ""),
      to: downcase_or_nil(raw["to"]),
      value: value_wei,
      value_decimal: wei_to_decimal(value_wei, decimals),
      gas: parse_integer(raw["gas"]),
      gas_price: parse_integer_or_nil(raw["gasPrice"]),
      gas_used: parse_integer_or_nil(raw["gasUsed"]),
      nonce: parse_integer(raw["nonce"] || "0"),
      input: raw["input"] || "0x",
      status: parse_tx_status(raw),
      timestamp: parse_timestamp(raw["timeStamp"] || raw["timestamp"]),
      transaction_index: parse_integer_or_nil(raw["transactionIndex"])
    }
  end

  @doc """
  Normalizes a raw event/log response into an Event struct.

  ## Parameters

  - `raw` - Map with string keys from API response
  - `chain` - Chain atom identifier
  - `chain_id` - Numeric chain ID
  """
  @spec normalize_event(map(), atom(), pos_integer()) :: Event.t()
  def normalize_event(raw, chain, chain_id) do
    %Event{
      chain: chain,
      chain_id: chain_id,
      address: String.downcase(raw["address"] || ""),
      topics: parse_topics(raw["topics"]),
      data: raw["data"] || "0x",
      block_number: parse_integer(raw["blockNumber"]),
      block_hash: raw["blockHash"],
      transaction_hash: raw["transactionHash"],
      transaction_index: parse_integer_or_nil(raw["transactionIndex"]),
      log_index: parse_integer(raw["logIndex"] || "0"),
      removed: raw["removed"] == true || raw["removed"] == "true",
      event_name: raw["eventName"],
      decoded_data: raw["decodedData"],
      timestamp: parse_timestamp(raw["timeStamp"] || raw["timestamp"])
    }
  end

  @doc """
  Normalizes a raw balance response into a TokenBalance struct.

  ## Parameters

  - `raw` - Map with string keys from API response
  - `chain` - Chain atom identifier
  - `chain_id` - Numeric chain ID
  - `opts` - Additional options (`:address`, `:token_type`)
  """
  @spec normalize_token_balance(map() | String.t(), atom(), pos_integer(), keyword()) ::
          TokenBalance.t()
  def normalize_token_balance(raw, chain, chain_id, opts \\ [])

  def normalize_token_balance(raw, chain, chain_id, opts) when is_binary(raw) do
    # Simple balance string (native currency)
    decimals = chain_decimals(chain)
    native_currency = chain_native_currency(chain)

    %TokenBalance{
      chain: chain,
      chain_id: chain_id,
      address: opts[:address] || "",
      contract_address: nil,
      token_name: native_currency,
      token_symbol: native_currency,
      token_decimals: decimals,
      balance_raw: raw,
      balance_formatted: wei_to_decimal(raw, decimals),
      token_type: :native,
      last_updated: DateTime.utc_now()
    }
  end

  def normalize_token_balance(raw, chain, chain_id, opts) when is_map(raw) do
    decimals = parse_integer(raw["tokenDecimal"] || raw["decimals"] || "18")
    balance = raw["balance"] || raw["result"] || "0"

    %TokenBalance{
      chain: chain,
      chain_id: chain_id,
      address: opts[:address] || raw["address"] || "",
      contract_address: raw["contractAddress"] || raw["TokenAddress"],
      token_name: raw["tokenName"] || raw["name"],
      token_symbol: raw["tokenSymbol"] || raw["symbol"],
      token_decimals: decimals,
      balance_raw: balance,
      balance_formatted: wei_to_decimal(balance, decimals),
      token_type: Keyword.get(opts, :token_type, :erc20),
      last_updated: DateTime.utc_now()
    }
  end

  @doc """
  Normalizes a gas oracle response into a GasPrice struct.

  ## Parameters

  - `raw` - Map with string keys from API response
  - `chain` - Chain atom identifier
  - `chain_id` - Numeric chain ID
  """
  @spec normalize_gas_price(map(), atom(), pos_integer()) :: GasPrice.t()
  def normalize_gas_price(raw, chain, chain_id) do
    %GasPrice{
      chain: chain,
      chain_id: chain_id,
      safe_gas_price: parse_float(raw["SafeGasPrice"] || raw["safeGasPrice"] || "0"),
      propose_gas_price: parse_float(raw["ProposeGasPrice"] || raw["proposeGasPrice"] || "0"),
      fast_gas_price: parse_float(raw["FastGasPrice"] || raw["fastGasPrice"] || "0"),
      base_fee: parse_float_or_nil(raw["suggestBaseFee"] || raw["baseFee"]),
      unit: "gwei",
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Converts a wei value string to a decimal value with the given number of decimals.

  ## Examples

      iex> Lux.MultiChain.Normalizer.wei_to_decimal("1000000000000000000", 18)
      1.0

      iex> Lux.MultiChain.Normalizer.wei_to_decimal("500000000000000000", 18)
      0.5
  """
  @spec wei_to_decimal(String.t() | integer(), pos_integer()) :: float()
  def wei_to_decimal("0x" <> hex, decimals) do
    case Integer.parse(hex, 16) do
      {int_val, _} -> wei_to_decimal(int_val, decimals)
      :error -> 0.0
    end
  end

  def wei_to_decimal(value, decimals) when is_binary(value) do
    case Integer.parse(value) do
      {int_val, _} -> wei_to_decimal(int_val, decimals)
      :error -> 0.0
    end
  end

  def wei_to_decimal(value, decimals) when is_integer(value) do
    divisor = :math.pow(10, decimals)
    value / divisor
  end

  # Internal helpers

  defp parse_integer(nil), do: 0

  defp parse_integer("0x" <> hex) do
    case Integer.parse(hex, 16) do
      {val, _} -> val
      :error -> 0
    end
  end

  defp parse_integer(val) when is_binary(val) do
    case Integer.parse(val) do
      {int_val, _} -> int_val
      :error -> 0
    end
  end

  defp parse_integer(val) when is_integer(val), do: val

  defp parse_integer_or_nil(nil), do: nil

  defp parse_integer_or_nil(val) do
    result = parse_integer(val)
    if result == 0 and val != "0" and val != 0, do: nil, else: result
  end

  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {f, _} -> f
      :error -> 0.0
    end
  end

  defp parse_float(val) when is_float(val), do: val
  defp parse_float(val) when is_integer(val), do: val / 1
  defp parse_float(_), do: 0.0

  defp parse_float_or_nil(nil), do: nil
  defp parse_float_or_nil(val), do: parse_float(val)

  defp parse_timestamp(nil), do: nil

  defp parse_timestamp(ts) when is_binary(ts) do
    case Integer.parse(ts) do
      {unix_ts, _} ->
        case DateTime.from_unix(unix_ts) do
          {:ok, dt} -> dt
          _ -> nil
        end

      :error ->
        nil
    end
  end

  defp parse_timestamp(ts) when is_integer(ts) do
    case DateTime.from_unix(ts) do
      {:ok, dt} -> dt
      _ -> nil
    end
  end

  defp parse_tx_status(%{"txreceipt_status" => "1"}), do: :success
  defp parse_tx_status(%{"txreceipt_status" => "0"}), do: :failure
  defp parse_tx_status(%{"isError" => "0"}), do: :success
  defp parse_tx_status(%{"isError" => "1"}), do: :failure
  defp parse_tx_status(%{"status" => "0x1"}), do: :success
  defp parse_tx_status(%{"status" => "0x0"}), do: :failure
  defp parse_tx_status(_), do: :pending

  defp parse_topics(nil), do: []
  defp parse_topics(topics) when is_list(topics), do: topics
  defp parse_topics(_), do: []

  defp downcase_or_nil(nil), do: nil
  defp downcase_or_nil(""), do: nil
  defp downcase_or_nil(s) when is_binary(s), do: String.downcase(s)

  defp chain_decimals(chain) do
    case Lux.Chain.get(chain) do
      nil -> 18
      c -> c.currency_decimals
    end
  end

  defp chain_native_currency(chain) do
    case Lux.Chain.get(chain) do
      nil -> "ETH"
      c -> c.native_currency
    end
  end
end
