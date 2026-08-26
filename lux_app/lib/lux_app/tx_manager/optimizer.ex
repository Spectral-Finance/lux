defmodule LuxApp.TxManager.Optimizer do
  @moduledoc """
  Priority fee optimization and EIP-1559 strategies.
  """

  @doc """
  Calculates maxFeePerGas and maxPriorityFeePerGas based on the current base fee and strategy.
  Strategies: :economy, :standard, :fast
  """
  def calculate_eip1559_fees(base_fee, strategy) do
    priority_fee = get_priority_fee(strategy)
    
    # maxFeePerGas = (base_fee * 2) + priority_fee (Standard EIP-1559 formula)
    max_fee = (base_fee * 2) + priority_fee

    %{
      max_fee_per_gas: trunc(max_fee),
      max_priority_fee_per_gas: trunc(priority_fee)
    }
  end

  # Returns priority fee in Wei (1 gwei = 1_000_000_000 wei)
  defp get_priority_fee(:economy), do: 1_000_000_000
  defp get_priority_fee(:standard), do: 2_000_000_000
  defp get_priority_fee(:fast), do: 5_000_000_000
end
