defmodule LuxApp.TxManager.Simulator do
  @moduledoc """
  Transaction simulation engine for EVM dry-runs before submission.
  """

  @rpc_adapter Application.compile_env(:lux_app, :rpc_adapter, LuxApp.TxManager.RealRPC)

  def estimate(tx) do
    @rpc_adapter.estimate_gas(tx)
  end
end
