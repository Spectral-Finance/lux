defmodule Lux.Web3.EventMonitor.SyncPlan do
  @moduledoc """
  Splits historical event sync work into bounded block ranges.
  """

  alias Lux.Web3.EventMonitor.Subscription

  @type range :: %{from_block: non_neg_integer(), to_block: non_neg_integer()}

  @spec ranges(Subscription.t(), non_neg_integer(), pos_integer()) :: [range()]
  def ranges(%Subscription{} = subscription, latest_block, batch_size \\ 2_000)
      when is_integer(latest_block) and latest_block >= 0 and is_integer(batch_size) and batch_size > 0 do
    final_block = resolve_to_block(subscription.to_block, latest_block)

    if subscription.from_block > final_block do
      []
    else
      subscription.from_block
      |> Stream.iterate(&(&1 + batch_size))
      |> Enum.take_while(&(&1 <= final_block))
      |> Enum.map(fn from_block ->
        %{from_block: from_block, to_block: min(from_block + batch_size - 1, final_block)}
      end)
    end
  end

  @spec next_from_block([map()], non_neg_integer()) :: non_neg_integer()
  def next_from_block([], fallback), do: fallback

  def next_from_block(events, fallback) do
    events
    |> Enum.map(&Map.get(&1, :block_number, fallback - 1))
    |> Enum.max()
    |> Kernel.+(1)
  end

  defp resolve_to_block(:latest, latest_block), do: latest_block
  defp resolve_to_block(to_block, _latest_block), do: to_block
end
