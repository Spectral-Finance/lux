defmodule Lux.LLM.Ollama.ResourcePool do
  @moduledoc """
  Simple semaphore-based pool used to bound the number of concurrent
  Ollama requests.
  """

  use GenServer

  @type option :: {:size, pos_integer()} | {:name, GenServer.name()}

  @default_size 2

  ## Public API

  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec checkout(GenServer.name()) :: :ok | {:error, :timeout}
  def checkout(pool_name \\ __MODULE__) do
    checkout(pool_name, 5_000)
  end

  @spec checkout(GenServer.name(), timeout()) :: :ok | {:error, :timeout}
  def checkout(pool_name, timeout) do
    GenServer.call(pool_name, {:checkout, self()}, timeout)
  catch
    :exit, {:timeout, _} -> {:error, :timeout}
  end

  @spec checkin(GenServer.name()) :: :ok
  def checkin(pool_name \\ __MODULE__) do
    GenServer.cast(pool_name, {:checkin, self()})
  end

  ## GenServer callbacks

  @impl true
  def init(opts) do
    limit =
      opts
      |> Keyword.get_lazy(:size, fn -> configured_size() end)
      |> max(1)

    state = %{
      available: limit,
      limit: limit,
      queue: :queue.new(),
      monitors: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:checkout, pid}, _from, %{available: available} = state) when available > 0 do
    ref = Process.monitor(pid)
    monitors = Map.put(state.monitors, pid, ref)
    {:reply, :ok, %{state | available: available - 1, monitors: monitors}}
  end

  def handle_call({:checkout, pid}, from, %{queue: queue} = state) do
    ref = Process.monitor(pid)
    monitors = Map.put(state.monitors, pid, ref)
    queue = :queue.in({from, pid}, queue)
    {:noreply, %{state | queue: queue, monitors: monitors}}
  end

  @impl true
  def handle_cast({:checkin, pid}, state) do
    state
    |> demonitor(pid)
    |> dispatch_next()
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    state
    |> demonitor(pid)
    |> dispatch_next()
    |> then(&{:noreply, &1})
  end

  ## Helpers

  defp demonitor(%{monitors: monitors} = state, pid) do
    case Map.pop(monitors, pid) do
      {nil, monitors} -> %{state | monitors: monitors}
      {ref, monitors} ->
        Process.demonitor(ref, [:flush])
        %{state | monitors: monitors}
    end
  end

  defp dispatch_next(%{queue: queue} = state) do
    case :queue.out(queue) do
      {{:value, {from, pid}}, new_queue} ->
        if Map.has_key?(state.monitors, pid) do
          GenServer.reply(from, :ok)
          %{state | queue: new_queue}
        else
          dispatch_next(%{state | queue: new_queue})
        end

      {:empty, _queue} ->
        %{state | available: min(state.available + 1, state.limit)}
    end
  end

  defp configured_size do
    case Application.get_env(:lux, Lux.LLM.Ollama, []) do
      nil -> @default_size
      keyword when is_list(keyword) -> Keyword.get(keyword, :max_concurrency, @default_size)
      map when is_map(map) -> Map.get(map, :max_concurrency, @default_size)
      value when is_integer(value) -> value
      _ -> @default_size
    end
  end
end
