defmodule Lux.Integrations.Twitter.ContentManager do
  @moduledoc """
  Content management system for curating and organizing tweets.
  """
  use GenServer

  # Client

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts ++ [name: __MODULE__])
  end

  def add_content(content) do
    GenServer.cast(__MODULE__, {:add, content})
  end

  def get_random() do
    GenServer.call(__MODULE__, :get_random)
  end

  def list_all() do
    GenServer.call(__MODULE__, :list_all)
  end

  # Server

  @impl true
  def init(_) do
    {:ok, []}
  end

  @impl true
  def handle_cast({:add, content}, state) do
    {:noreply, [content | state]}
  end

  @impl true
  def handle_call(:get_random, _from, []) do
    {:reply, nil, []}
  end

  @impl true
  def handle_call(:get_random, _from, state) do
    item = Enum.random(state)
    {:reply, item, state}
  end

  @impl true
  def handle_call(:list_all, _from, state) do
    {:reply, state, state}
  end
end
