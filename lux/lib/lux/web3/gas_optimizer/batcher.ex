defmodule Lux.Web3.GasOptimizer.Batcher do
  @moduledoc """
  Transaction batching and Multicall3 bundle constructor.

  Combines multiple contract calls or transfers into a single batched execution
  plan and calculates intrinsic gas savings (`21,000` base tx gas saved per
  additional call minus small calldata overhead).
  """

  @multicall3_address "0xcA11bde05977b3631167028862bE2a173976CA11"
  @base_tx_gas 21_000
  @per_call_dispatch_overhead 2_600

  @type call_item :: %{
          to: String.t(),
          value: non_neg_integer(),
          data: String.t(),
          gas_estimate: pos_integer(),
          allow_failure: boolean()
        }

  @doc """
  Builds a Multicall3 batched transaction plan from a list of individual calls
  and computes the gas savings compared to standalone transactions.
  """
  @spec build_batch([map()], keyword()) :: {:ok, map()} | {:error, :empty_batch}
  def build_batch([], _opts), do: {:error, :empty_batch}

  def build_batch(calls, opts \\ []) when is_list(calls) do
    multicall_address = Keyword.get(opts, :multicall_address, @multicall3_address)
    normalized_calls = Enum.map(calls, &normalize_call/1)
    call_count = length(normalized_calls)

    standalone_gas =
      Enum.reduce(normalized_calls, 0, fn c, acc ->
        acc + @base_tx_gas + c.gas_estimate
      end)

    execution_gas = Enum.reduce(normalized_calls, 0, &(&1.gas_estimate + &2))
    batched_gas = @base_tx_gas + execution_gas + call_count * @per_call_dispatch_overhead
    saved_gas = max(0, standalone_gas - batched_gas)
    savings_pct = Float.round(saved_gas / max(1, standalone_gas) * 100.0, 2)
    total_value = Enum.reduce(normalized_calls, 0, &(&1.value + &2))

    encoded_data = encode_multicall_payload(normalized_calls)

    {:ok,
     %{
       to: multicall_address,
       value: total_value,
       data: encoded_data,
       call_count: call_count,
       calls: normalized_calls,
       standalone_gas: standalone_gas,
       batched_gas: batched_gas,
       gas_saved: saved_gas,
       savings_percentage: savings_pct
     }}
  end

  defp normalize_call(call) when is_map(call) do
    %{
      to: Map.get(call, :to) || Map.get(call, "to"),
      value: Map.get(call, :value) || Map.get(call, "value") || 0,
      data: Map.get(call, :data) || Map.get(call, "data") || "0x",
      gas_estimate: Map.get(call, :gas_estimate) || Map.get(call, "gas_estimate") || 35_000,
      allow_failure: Map.get(call, :allow_failure, false)
    }
  end

  defp encode_multicall_payload(calls) do
    # Multicall3 aggregate3Value(Call3Value[]) selector: 0x174dea71
    payload =
      calls
      |> Enum.map(&{&1.to, &1.allow_failure, &1.value, &1.data})
      |> :erlang.term_to_binary()
      |> Base.encode16(case: :lower)

    "0x174dea71" <> payload
  end
end
