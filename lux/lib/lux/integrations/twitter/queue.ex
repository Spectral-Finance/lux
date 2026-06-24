defmodule Lux.Integrations.Twitter.Queue do
  @moduledoc """
  A simple queue management for scheduled tweets.
  """
  use GenServer

  # Client

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts ++ [name: __MODULE__])
  end

  def enqueue(tweet, scheduled_for \\ nil) do
    GenServer.cast(__MODULE__, {:enqueue, %{text: tweet, scheduled_for: scheduled_for || DateTime.utc_now()}})
  end

  def dequeue_due() do
    GenServer.call(__MODULE__, :dequeue_due)
  end

  def list_all() do
    GenServer.call(__MODULE__, :list_all)
  end

  def clear() do
    GenServer.cast(__MODULE__, :clear)
  end

  # Server

  @impl true
  def init(_) do
    {:ok, []}
  end

  @impl true
  def handle_cast({:enqueue, item}, state) do
    {:noreply, [item | state]}
  end

  @impl true
  def handle_cast(:clear, _state) do
    {:noreply, []}
  end

  @impl true
  def handle_call(:dequeue_due, _from, state) do
    now = DateTime.utc_now()
    {due, not_due} = Enum.split_with(state, fn item ->
      DateTime.compare(item.scheduled_for, now) != :gt
    end)
    {:reply, due, not_due}
  end

  @impl true
  def handle_call(:list_all, _from, state) do
    {:reply, state, state}
  end
end
