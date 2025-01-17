defmodule Lux.Engine.Queue.DistributedQueue do
  @moduledoc """
  Distributed queue implementation using :queue and Phoenix.PubSub.
  """

  use GenServer
  alias Phoenix.PubSub

  @max_queue_size 10_000

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    {:ok, pid} = GenServer.start_link(__MODULE__, opts, name: via_tuple(name))
    {:ok, pid}
  end

  def push(name, item) do
    GenServer.call(via_tuple(name), {:push, item})
  end

  def pop(name) do
    GenServer.call(via_tuple(name), :pop)
  end

  def subscribe(name) do
    PubSub.subscribe(Lux.PubSub, topic(name))
  end

  def unsubscribe(name) do
    PubSub.unsubscribe(Lux.PubSub, topic(name))
  end

  @impl true
  def init(opts) do
    state = %{
      topic: topic(Keyword.fetch!(opts, :name)),
      queue: :queue.new(),
      max_size: Keyword.get(opts, :max_size, @max_queue_size)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:push, item}, _from, state) do
    queue_length = :queue.len(state.queue)

    if queue_length >= state.max_size do
      {:reply, {:error, :queue_full}, state}
    else
      new_queue = :queue.in(item, state.queue)
      broadcast_update(state.topic, {:pushed, item})
      {:reply, :ok, %{state | queue: new_queue}}
    end
  end

  def handle_call(:pop, _from, state) do
    case :queue.out(state.queue) do
      {{:value, item}, new_queue} ->
        broadcast_update(state.topic, {:popped, item})
        {:reply, {:ok, item}, %{state | queue: new_queue}}

      {:empty, _} ->
        {:reply, {:error, :empty}, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  defp broadcast_update(topic, message) do
    PubSub.broadcast(Lux.PubSub, topic, message)
  end

  defp topic(name), do: "queue:#{name}"

  defp via_tuple(name) do
    {:via, Registry, {Lux.Engine.Registry, name}}
  end
end
