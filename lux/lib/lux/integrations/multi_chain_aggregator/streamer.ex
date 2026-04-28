defmodule Lux.Integrations.MultiChainAggregator.Streamer do
  @moduledoc """
  Real-time data streaming using GenStage for backpressure-aware
  event distribution to subscribers.
  """

  use GenStage

  def start_link(chain, _config) do
    GenStage.start_link(__MODULE__, chain, name: via(chain))
  end

  def init(chain) do
    {:producer, %{chain: chain, demand: 0, queue: []}}
  end

  def emit(chain, event) do
    GenStage.cast(via(chain), {:emit, event})
  end

  def subscribe(chain, subscriber) do
    GenStage.sync_subscribe(subscriber, to: via(chain))
  end

  def handle_demand(demand, state) do
    {events, remaining} = Enum.split(state.queue, demand)
    {:noreply, events, %{state | demand: demand - length(events), queue: remaining}}
  end

  def handle_cast({:emit, event}, state) do
    if state.demand > 0 do
      {:noreply, [event], %{state | demand: state.demand - 1}}
    else
      {:noreply, [], %{state | queue: state.queue ++ [event]}}
    end
  end

  defp via(chain), do: {:via, Registry, {Lux.Registry, {:streamer, chain}}}
end