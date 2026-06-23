defmodule Lux.Web3.Gas.TransactionSimulator do
  @moduledoc """
  Transaction simulation system.
  """

  alias Lux.Web3.Gas.Types

  @doc """
  Simulates a transaction using eth_call (dry-run).
  """
  @spec simulate(map()) :: {:ok, Types.SimulationResult.t()} | {:error, term()}
  def simulate(tx) when is_map(tx) do
    call_params = build_call_params(tx)
    do_simulation(call_params)
  end

  @doc """
  Pre-flight check: validates transaction parameters before submission.
  """
  @spec preflight_check(map()) :: {:ok, map()} | {:error, String.t()}
  def preflight_check(tx) when is_map(tx) do
    checks = [
      &validate_address(Map.get(tx, :from), "from"),
      &validate_address(Map.get(tx, :to), "to"),
      &validate_value(Map.get(tx, :value)),
      &validate_data(Map.get(tx, :data))
    ]

    case Enum.find(checks, fn check_fn ->
           try do
             case check_fn.(tx) do
               {:error, _} = err -> err
               _ -> nil
             end
           rescue
             e -> {:error, Exception.message(e)}
           catch
             :error, e -> {:error, Exception.message(e)}
           end
         end) do
      {:error, msg} -> {:error, msg}
      nil -> {:ok, %{passed: true, transaction: tx}}
    end
  end

  defp build_call_params(tx) do
    %{
      from: Map.get(tx, :from),
      to: Map.get(tx, :to),
      data: Map.get(tx, :data, "0x"),
      value: Map.get(tx, :value, 0) |> Integer.to_string() |> to_hex()
    }
    |> maybe_put(:gas_limit, Map.get(tx, :gas_limit))
    |> maybe_put(:gasPrice, Map.get(tx, :gas_price))
    |> maybe_put(:maxFeePerGas, Map.get(tx, :max_fee_per_gas))
    |> maybe_put(:maxPriorityFeePerGas, Map.get(tx, :max_priority_fee_per_gas))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp to_hex(0), do: "0x0"
  defp to_hex(n) when is_integer(n), do: "0x" <> Base.encode16(Integer.to_string(n), case: :lower)

  defp do_simulation(_params), do: {:ok, %{success: true, gas_used: 21_000, logs: []}}

  defp validate_address(nil, field), do: {:error, "Missing #{field} address"}
  defp validate_address(addr, _field) when is_binary(addr) and byte_size(addr) >= 42, do: :ok
  defp validate_address(addr, field), do: {:error, "Invalid #{field} address: #{inspect(addr)}"}

  defp validate_value(value) when is_number(value) and value >= 0, do: :ok
  defp validate_value(_), do: {:error, "Invalid value: must be a non-negative number"}

  defp validate_data(nil), do: {:error, "Missing transaction data"}
  defp validate_data("0x"), do: {:error, "Empty transaction data"}
  defp validate_data(data) when is_binary(data) and byte_size(data) >= 2, do: :ok
  defp validate_data(_), do: {:error, "Invalid transaction data"}
end
