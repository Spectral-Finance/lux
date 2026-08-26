defmodule LuxApp.TxManager.GasToken do
  @moduledoc """
  Integrates Gas Tokens (CHI/GST2) to reduce transaction costs by freeing storage via ABI encoding.
  Executes storage release via Multicall3 aggregate3 / aggregate3Value atomic batching.
  """
  import LuxApp.TxManager.ABIEncoder, only: [pad_uint256: 1, encode_multicall: 1, encode_multicall_value: 1]

  # Selector for freeFromUpTo(address,uint256) = 0xd7db9b35
  @free_from_up_to_selector "d7db9b35"
  @multicall_address "0xcA11bde05977b3631167028862bE2a173976CA11"

  @doc """
  Wraps a transaction payload into a Multicall3 aggregate3 / aggregate3Value bundle that frees storage via gas tokens first.
  Preserves caller semantics and per-call ETH values.
  """
  def wrap_with_gas_token(tx, token_address, amount, holder_address \\ nil) when is_integer(amount) do
    holder = holder_address || Map.get(tx, :from) || Map.get(tx, "from", "0x0000000000000000000000000000000000000000")
    tx_value = Map.get(tx, :value) || Map.get(tx, "value", 0)

    free_call_data = encode_free_from_up_to(holder, amount)
    
    if tx_value > 0 do
      free_call = %{
        to: token_address,
        allow_failure: false,
        value: 0,
        data: "0x" <> free_call_data
      }

      target_call = %{
        to: Map.get(tx, :to) || Map.get(tx, "to", "0x0000000000000000000000000000000000000000"),
        allow_failure: false,
        value: tx_value,
        data: Map.get(tx, :data) || Map.get(tx, "data", "0x")
      }

      multicall_data = encode_multicall_value([free_call, target_call])

      %{
        to: @multicall_address,
        value: tx_value,
        data: multicall_data
      }
    else
      free_call = %{
        to: token_address,
        allow_failure: false,
        data: "0x" <> free_call_data
      }

      target_call = %{
        to: Map.get(tx, :to) || Map.get(tx, "to", "0x0000000000000000000000000000000000000000"),
        allow_failure: false,
        data: Map.get(tx, :data) || Map.get(tx, "data", "0x")
      }

      multicall_data = encode_multicall([free_call, target_call])

      %{
        to: @multicall_address,
        value: 0,
        data: multicall_data
      }
    end
  end

  @doc """
  Encodes freeFromUpTo(address,uint256) according to Solidity ABI specifications.
  """
  def encode_free_from_up_to(holder_address, amount) do
    clean_addr = String.replace(holder_address, "0x", "") |> String.pad_leading(64, "0") |> String.downcase()
    amount_hex = pad_uint256(amount)

    @free_from_up_to_selector <> clean_addr <> amount_hex
  end
end
