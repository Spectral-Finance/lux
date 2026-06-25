defmodule Lux.Integrations.EventMonitor.Indexer do
  @moduledoc "In-memory event log indexer."
  defstruct events: [], by_address: %{}, by_block: %{}
  @spec new() :: %__MODULE__{}
  def new, do: %__MODULE__{}
  @spec insert(%__MODULE__{}, map()) :: %__MODULE__{}
  def insert(idx, event) do
    addr = event.contract || "unknown"
    block = event.block_number || 0
    %__MODULE__{idx | events: [event|idx.events],
      by_address: Map.update(idx.by_address, addr, [event], &[event|&1]),
      by_block: Map.update(idx.by_block, block, [event], &[event|&1])}
  end
  @spec query(%__MODULE__{}, map()) :: [map()]
  def query(idx, f) do
    idx.events
    |> Enum.filter(fn e -> is_nil(f[:contract_address]) or e.contract == f[:contract_address] end)
    |> Enum.filter(fn e -> (is_nil(f[:from_block]) or (e.block_number||0)>=f[:from_block]) and (is_nil(f[:to_block]) or (e.block_number||0)<=f[:to_block]) end)
    |> Enum.filter(fn e -> is_nil(f[:event_name]) or e.event == f[:event_name] end)
    |> Enum.reverse()
    |> case {&1, f[:limit]} -> if f[:limit], do: Enum.take(&1, f[:limit]), else: &1 end
  end
end