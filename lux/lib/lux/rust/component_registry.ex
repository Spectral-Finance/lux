defmodule Lux.Rust.ComponentRegistry do
  @moduledoc """
  Registry for Rust-backed components.

  Tracks registered components, their types, and status.
  Provides discovery and lifecycle management.
  """

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Register a Rust component module."
  def register(module) when is_atom(module) do
    GenServer.call(__MODULE__, {:register, module})
  end

  @doc "List all registered components."
  def list do
    GenServer.call(__MODULE__, :list)
  end

  @doc "Get info about a specific component."
  def info(module) do
    GenServer.call(__MODULE__, {:info, module})
  end

  @doc "Check if NIF is available for a component."
  def available?(module) do
    GenServer.call(__MODULE__, {:available?, module})
  end

  # Server

  @impl true
  def init(_opts) do
    {:ok, %{components: %{}}}
  end

  @impl true
  def handle_call({:register, module}, _from, state) do
    entry = %{
      module: module,
      type: module.__component_type__(),
      name: module.__component_name__(),
      description: module.__component_description__(),
      registered_at: DateTime.utc_now()
    }
    {:reply, :ok, put_in(state, [:components, module], entry)}
  end

  def handle_call(:list, _from, state) do
    {:reply, Map.values(state.components), state}
  end

  def handle_call({:info, module}, _from, state) do
    case Map.get(state.components, module) do
      nil -> {:reply, {:error, :not_found}, state}
      entry -> {:reply, {:ok, entry}, state}
    end
  end

  def handle_call({:available?, module}, _from, state) do
    result = try do
      module.__component_type__()
      Lux.Rust.available?()
    rescue
      _ -> false
    end
    {:reply, result, state}
  end
end
