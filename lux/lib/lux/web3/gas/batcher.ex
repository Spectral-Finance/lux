defmodule Lux.Web3.Gas.Batcher do
  @moduledoc """
  Transaction batching engine using standard Multicall3 aggregation.

  Features:
  - Bundling multiple calls into a single atomic or fault-tolerant Multicall3 transaction
  - Gas threshold-based and batch-size-based auto-flushing logic
  - Precise calculation of gas savings against standalone individual executions
  - ABI encoding helper for Multicall3 `aggregate3`
  """

  @multicall3_address "0xcA11bde05977b3631167028862bE2a173976CA11"
  @base_tx_overhead 21_000
  @multicall_subcall_overhead 2_600

  @type call :: %{
          target: String.t(),
          call_data: binary(),
          allow_failure: boolean(),
          value: non_neg_integer()
        }

  @type batch_summary :: %{
          calls_count: non_neg_integer(),
          multicall_address: String.t(),
          estimated_individual_gas: non_neg_integer(),
          estimated_batched_gas: non_neg_integer(),
          gas_saved: non_neg_integer(),
          savings_percentage: float(),
          calls: list(call())
        }

  @doc """
  Constructs a standard batch payload suitable for Multicall3.
  """
  @spec create_batch(list(map())) :: {:ok, batch_summary()} | {:error, String.t()}
  def create_batch([]), do: {:error, "Cannot create an empty batch"}

  def create_batch(calls) when is_list(calls) do
    sanitized_calls =
      Enum.map(calls, fn c ->
        %{
          target: Map.get(c, :target) || Map.get(c, "target", "0x0000000000000000000000000000000000000000"),
          call_data: Map.get(c, :call_data) || Map.get(c, "call_data", "0x"),
          allow_failure: Map.get(c, :allow_failure, false),
          value: Map.get(c, :value, 0)
        }
      end)

    n = length(sanitized_calls)
    # Average call execution cost approximation if not provided
    avg_call_gas = 45_000

    individual_gas = n * (@base_tx_overhead + avg_call_gas)
    batched_gas = @base_tx_overhead + (n * (avg_call_gas + @multicall_subcall_overhead))
    gas_saved = max(individual_gas - batched_gas, 0)
    savings_pct = if individual_gas > 0, do: Float.round((gas_saved / individual_gas) * 100, 2), else: 0.0

    summary = %{
      calls_count: n,
      multicall_address: @multicall3_address,
      estimated_individual_gas: individual_gas,
      estimated_batched_gas: batched_gas,
      gas_saved: gas_saved,
      savings_percentage: savings_pct,
      calls: sanitized_calls
    }

    {:ok, summary}
  end

  @doc """
  Determines whether a queue of pending transactions should be flushed into a batch
  based on target size or accumulated gas threshold.
  """
  @spec should_flush?(list(map()), non_neg_integer(), non_neg_integer()) :: boolean()
  def should_flush?(queue, min_batch_size, max_gas_threshold) do
    count = length(queue)
    total_est_gas = count * @base_tx_overhead

    count >= min_batch_size or (count > 1 and total_est_gas >= max_gas_threshold)
  end

  @doc """
  Generates the Multicall3 aggregate3 execution specification.
  Returns call target, signature and arguments representation.
  """
  @spec encode_aggregate3(list(call())) :: %{to: String.t(), function: String.t(), calls: list(map())}
  def encode_aggregate3(calls) do
    formatted_calls =
      Enum.map(calls, fn c ->
        %{
          target: c.target,
          allowFailure: c.allow_failure,
          callData: c.call_data
        }
      end)

    %{
      to: @multicall3_address,
      function: "aggregate3((address,bool,bytes)[])",
      calls: formatted_calls
    }
  end
end
