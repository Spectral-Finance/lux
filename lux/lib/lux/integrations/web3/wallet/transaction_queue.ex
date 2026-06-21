defmodule Lux.Integrations.Web3.Wallet.TransactionQueue do
  @moduledoc """
  Queue manager for wallet transactions to handle nonces and batching.
  """
  use Agent

  def start_link(_opts \\ []) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def enqueue(wallet_name, tx_data) do
    Agent.update(__MODULE__, fn state ->
      queue = Map.get(state, wallet_name, :queue.new())
      Map.put(state, wallet_name, :queue.in(tx_data, queue))
    end)
    :ok
  end

  def dequeue(wallet_name) do
    Agent.get_and_update(__MODULE__, fn state ->
      queue = Map.get(state, wallet_name, :queue.new())
      case :queue.out(queue) do
        {{:value, tx}, new_queue} ->
          {{:ok, tx}, Map.put(state, wallet_name, new_queue)}
        {:empty, _} ->
          {:empty, state}
      end
    end)
  end
  
  def clear(wallet_name) do
    Agent.update(__MODULE__, fn state -> Map.put(state, wallet_name, :queue.new()) end)
  end
end
