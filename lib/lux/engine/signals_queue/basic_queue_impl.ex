defmodule Lux.Engine.SignalsQueue.BasicQueueImpl do
  @moduledoc """
  Basic implementation of SignalQueue using a GenServer and :queue.
  """

  use GenServer
  @behaviour Lux.Engine.SignalsQueue

  defmodule State do
    @moduledoc false
    defstruct [:queue]
  end

  # SignalsQueue Behaviour Implementation

  @impl Lux.Engine.SignalsQueue
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name)
    GenServer.start_link(__MODULE__, [], name: name)
  end

  @impl Lux.Engine.SignalsQueue
  def push(pid, %Lux.Signal{} = signal) do
    GenServer.call(pid, {:push, signal})
  end

  @impl Lux.Engine.SignalsQueue
  def pop(pid) do
    GenServer.call(pid, :pop)
  end

  @impl Lux.Engine.SignalsQueue
  def length(pid) do
    GenServer.call(pid, :length)
  end

  @impl Lux.Engine.SignalsQueue
  def cleanup(pid) do
    GenServer.call(pid, :cleanup)
  end

  @impl Lux.Engine.SignalsQueue
  def to_list(pid) do
    GenServer.call(pid, :to_list)
  end

  # GenServer Implementation

  @impl GenServer
  def init(:ok) do
    {:ok, %State{queue: :queue.new()}}
  end

  @impl GenServer
  def handle_call({:push, signal}, _from, %State{queue: queue} = state) do
    {:reply, :ok, %{state | queue: :queue.in(signal, queue)}}
  end

  def handle_call(:pop, _from, %State{queue: queue} = state) do
    case :queue.out(queue) do
      {{:value, signal}, new_queue} ->
        {:reply, {:ok, signal}, %{state | queue: new_queue}}

      {:empty, _} ->
        {:reply, {:empty, nil}, state}
    end
  end

  def handle_call(:length, _from, %State{queue: queue} = state) do
    {:reply, :queue.len(queue), state}
  end

  def handle_call(:cleanup, _from, state) do
    {:stop, :normal, :ok, %{state | queue: :queue.new()}}
  end

  def handle_call(:to_list, _from, %State{queue: queue} = state) do
    {:reply, :queue.to_list(queue), state}
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end
end
