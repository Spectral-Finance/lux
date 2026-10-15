defmodule Lux.Web3.GasOptimizer.Simulator do
  @moduledoc """
  Pre-flight EVM transaction simulator using `eth_call` and `eth_estimateGas`
  to verify execution success, decode revert reasons, and profile gas usage
  before broadcasting.
  """

  alias Lux.Web3.GasOptimizer.FeePredictor

  @doc """
  Simulates a transaction against an RPC endpoint (`eth_call` + `eth_estimateGas`)
  and returns a structured simulation report.
  """
  @spec simulate(map(), (String.t(), list() -> {:ok, term()} | {:error, term()})) ::
          {:ok, map()} | {:error, term()}
  def simulate(tx, rpc_caller) when is_map(tx) and is_function(rpc_caller, 2) do
    call_obj = %{
      "from" => Map.get(tx, :from),
      "to" => Map.get(tx, :to),
      "value" => int_to_hex(Map.get(tx, :value, 0)),
      "data" => Map.get(tx, :data, "0x")
    }

    case rpc_caller.("eth_call", [call_obj, "latest"]) do
      {:ok, return_data} ->
        case rpc_caller.("eth_estimateGas", [call_obj]) do
          {:ok, gas_hex} ->
            estimated_gas = FeePredictor.hex_to_int(gas_hex)

            {:ok,
             %{
               success: true,
               return_data: return_data,
               estimated_gas: estimated_gas,
               recommended_gas_limit: round(estimated_gas * 1.15),
               revert_reason: nil
             }}

          {:error, reason} ->
            {:ok,
             %{
               success: false,
               return_data: nil,
               estimated_gas: 0,
               recommended_gas_limit: 0,
               revert_reason: format_revert_reason(reason)
             }}
        end

      {:error, reason} ->
        {:ok,
         %{
           success: false,
           return_data: nil,
           estimated_gas: 0,
           recommended_gas_limit: 0,
           revert_reason: format_revert_reason(reason)
         }}
    end
  end

  defp format_revert_reason({:rpc_error, %{"message" => msg}}), do: msg
  defp format_revert_reason(reason) when is_binary(reason), do: reason
  defp format_revert_reason(other), do: inspect(other)

  defp int_to_hex(0), do: "0x0"

  defp int_to_hex(val) when is_integer(val) and val > 0 do
    "0x" <> String.downcase(Integer.to_string(val, 16))
  end
end
