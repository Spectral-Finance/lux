defmodule LuxApp.TxManager do
  @moduledoc """
  Context facade for Gas Optimization and Transaction Management.
  """
  alias LuxApp.TxManager.{GasOracle, Batcher, Optimizer, Replacer, MevProtector, Simulator, Reporter, GasToken}

  @rpc_adapter Application.compile_env(:lux_app, :rpc_adapter, LuxApp.TxManager.RealRPC)

  def delegate_estimate_gas(tx), do: Simulator.estimate(tx)
  
  def optimize_gas_fees(strategy \\ :standard) do
    case GasOracle.get_current_base_fee() do
      {:ok, base_fee} -> {:ok, Optimizer.calculate_eip1559_fees(base_fee, strategy)}
      base_fee when is_integer(base_fee) -> {:ok, Optimizer.calculate_eip1559_fees(base_fee, strategy)}
      {:error, reason} -> {:error, reason}
    end
  end

  def protect_transaction(tx, options \\ []) do
    MevProtector.wrap_for_private_mempool(tx, options)
  end

  def speed_up(tx), do: Replacer.speed_up(tx)
  def cancel(tx), do: Replacer.cancel(tx)

  def batch_transactions(txs), do: Batcher.create_multicall(txs)
  
  def report_savings(original_txs, batched_tx), do: Reporter.calculate_savings(original_txs, batched_tx)
  
  def apply_gas_token(tx, token_address, amount), do: GasToken.wrap_with_gas_token(tx, token_address, amount)
  
  def wait_for_receipt(hash), do: @rpc_adapter.get_transaction_receipt(hash)
end
