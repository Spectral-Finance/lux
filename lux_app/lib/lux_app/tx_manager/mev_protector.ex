defmodule LuxApp.TxManager.MevProtector do
  @moduledoc """
  Protects transactions against Front-Running and Sandwich Attacks using private mempools (Flashbots / MEV-Share).
  """

  @rpc_adapter Application.compile_env(:lux_app, :rpc_adapter, LuxApp.TxManager.RealRPC)

  def wrap_for_private_mempool(tx, opts \\ []) do
    builder = Keyword.get(opts, :builder, "flashbots")
    slippage = Keyword.get(opts, :slippage, 0.01)

    case @rpc_adapter.send_private_transaction(tx, builder) do
      {:ok, hash} ->
        metadata = %{
          protection_enabled: true,
          routing: :private,
          builder: builder,
          slippage_tolerance: slippage
        }
        {:ok, hash, metadata}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
