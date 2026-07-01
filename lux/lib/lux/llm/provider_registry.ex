defmodule Lux.LLM.ProviderRegistry do
  @moduledoc """
  GenServer-based registry for LLM providers.
  Manages provider registration, lookup, and health status.
  """
  use GenServer

  # Client API
  def start_link(opts \\\\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.merge(opts, name: __MODULE__))
  end

  def register(provider_module, opts \\\\ []) do
    GenServer.call(__MODULE__, {:register, provider_module, opts})
  end

  def list do
    GenServer.call(__MODULE__, :list)
  end

  def get(name) do
    GenServer.call(__MODULE__, {:get, name})
  end

  def available do
    GenServer.call(__MODULE__, :available)
  end

  # Server callbacks
  @impl true
  def init(:ok) do
    {:ok, %{providers: %{}, order: []}}
  end

  @impl true
  def handle_call({:register, module, opts}, _from, state) do
    name = opts[:name] || module
    provider = %{
      module: module,
      name: name,
      models: opts[:models] || [],
      priority: opts[:priority] || 0,
      enabled: true,
      cost_per_token: opts[:cost_per_token] || 0.0
    }
    new_providers = Map.put(state.providers, name, provider)
    new_order = if name in state.order, do: state.order, else: state.order ++ [name]
    {:reply, :ok, %{state | providers: new_providers, order: new_order}}
  end

  @impl true
  def handle_call(:list, _from, state) do
    providers = Enum.map(state.order, fn name -> state.providers[name] end)
    {:reply, providers, state}
  end

  @impl true
  def handle_call({:get, name}, _from, state) do
    {:reply, Map.get(state.providers, name), state}
  end

  @impl true
  def handle_call(:available, _from, state) do
    available = Enum.filter(state.order, fn name ->
      provider = state.providers[name]
      provider && provider.enabled
    end)
    {:reply, Enum.map(available, fn name -> state.providers[name] end), state}
  end
end