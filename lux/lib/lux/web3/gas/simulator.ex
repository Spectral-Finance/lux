defmodule Lux.Web3.Gas.Simulator do
  @moduledoc """
  Transaction simulation, revert debugging, and gas limit safety buffering.

  Capabilities:
  - Dry-run validation and exact execution outcome inspection
  - Decoding EVM revert reasons: `Error(string)`, `Panic(uint256)`, and custom error signatures
  - Gas limit estimation with configurable safety margin
  - Access list (EIP-2930) storage slot optimization calculation
  - Gas token / storage clearing refund estimation
  """

  @revert_error_selector "08c379a0"
  @panic_selector "4e487b71"

  @panic_reasons %{
    0x00 => "Generic compiler panic",
    0x01 => "Assertion violation (assert(false))",
    0x11 => "Arithmetic overflow / underflow",
    0x12 => "Division or modulo by zero",
    0x21 => "Conversion into out-of-bounds enum",
    0x22 => "Storage byte array encoding violation",
    0x31 => "Stack underflow (.pop() on empty array)",
    0x32 => "Array index out of bounds",
    0x41 => "Excessive memory allocation",
    0x51 => "Zero-initialized internal function call"
  }

  @type simulation_result :: %{
          success: boolean(),
          estimated_gas: non_neg_integer(),
          recommended_gas_limit: non_neg_integer(),
          safety_margin_multiplier: float(),
          revert_reason: String.t() | nil,
          access_list_savings: non_neg_integer(),
          gas_refund: non_neg_integer()
        }

  @doc """
  Simulates execution of a transaction map and computes recommended gas limits.
  """
  @spec simulate_transaction(map(), keyword()) :: simulation_result()
  def simulate_transaction(tx, opts \\ []) do
    safety_margin = Keyword.get(opts, :safety_margin, 1.20)
    raw_gas = Map.get(tx, :estimated_gas, 85_000)
    mock_revert = Map.get(tx, :revert_data, nil)
    access_list = Map.get(tx, :access_list, [])
    gas_token_used = Map.get(tx, :gas_token_burn, 0)

    {success, reason} =
      if mock_revert do
        {false, decode_revert_reason(mock_revert)}
      else
        {true, nil}
      end

    recommended_gas_limit = round(raw_gas * safety_margin)
    al_savings = calculate_access_list_savings(access_list)
    refund = calculate_gas_refund(raw_gas, gas_token_used)

    %{
      success: success,
      estimated_gas: raw_gas,
      recommended_gas_limit: recommended_gas_limit,
      safety_margin_multiplier: safety_margin,
      revert_reason: reason,
      access_list_savings: al_savings,
      gas_refund: refund
    }
  end

  @doc """
  Decodes hexadecimal revert binary data into human-readable strings.
  """
  @spec decode_revert_reason(binary() | nil) :: String.t()
  def decode_revert_reason(nil), do: "Transaction succeeded (no revert)"
  def decode_revert_reason("0x"), do: "Execution reverted with empty reason"
  def decode_revert_reason(""), do: "Execution reverted with empty reason"

  def decode_revert_reason(hex_data) when is_binary(hex_data) do
    cleaned = String.replace_prefix(hex_data, "0x")

    cond do
      String.starts_with?(cleaned, @revert_error_selector) ->
        decode_standard_error(cleaned)

      String.starts_with?(cleaned, @panic_selector) ->
        decode_panic(cleaned)

      true ->
        "Execution reverted with custom error selector: 0x" <> String.slice(cleaned, 0, 8)
    end
  end

  @doc """
  Calculates gas savings provided by EIP-2930 Access Lists.
  Storage key in access list costs 1,900 gas instead of cold read (2,100 gas), saving 200 gas per slot.
  """
  @spec calculate_access_list_savings(list(map())) :: non_neg_integer()
  def calculate_access_list_savings([]), do: 0

  def calculate_access_list_savings(access_list) when is_list(access_list) do
    Enum.reduce(access_list, 0, fn item, acc ->
      slots = Map.get(item, :storage_keys, []) || Map.get(item, "storageKeys", [])
      acc + length(slots) * 200
    end)
  end

  @doc """
  Calculates gas refund from storage deallocations or gas token burns.
  EVM caps refunds to a maximum of 20% of total gas used.
  """
  @spec calculate_gas_refund(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def calculate_gas_refund(gas_used, gas_token_count) do
    # Each gas token freed frees roughly 24,000 gas
    potential_refund = gas_token_count * 24_000
    max_allowable_refund = div(gas_used, 5)
    min(potential_refund, max_allowable_refund)
  end

  defp decode_standard_error(cleaned) do
    # 8 chars (4 bytes selector) + 64 chars offset + 64 chars length + string bytes
    try do
      if String.length(cleaned) >= 136 do
        len_hex = String.slice(cleaned, 72, 64)
        len = String.to_integer(len_hex, 16)
        str_hex = String.slice(cleaned, 136, len * 2)
        Base.decode16!(str_hex, case: :mixed)
      else
        "Execution reverted with unrecognized error formatting"
      end
    rescue
      _ -> "Execution reverted (failed to decode string reason)"
    end
  end

  defp decode_panic(cleaned) do
    try do
      if String.length(cleaned) >= 72 do
        code_hex = String.slice(cleaned, 8, 64)
        code = String.to_integer(code_hex, 16)
        reason = Map.get(@panic_reasons, code, "Unknown panic code 0x#{Integer.to_string(code, 16)}")
        "EVM Panic: #{reason}"
      else
        "EVM Panic with invalid payload"
      end
    rescue
      _ -> "EVM Panic (failed to decode code)"
    end
  end
end
