defmodule Lux.LLM.Provider.Registry do
  @moduledoc """
  Provider Registry System
  
  Manages registration and configuration of LLM providers.
  """

  use GenServer

  @registry_name :lux_llm_providers

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @registry_name)
  end

  @impl true
  def init(_opts) do
    {:ok, %{providers: %{}, configs: %{}}}
  end

  @doc """
  Registers a new provider with its configuration
  """
  @spec register(atom(), module(), map()) :: :ok | {:error, any()}
  def register(name, module, config) do
    GenServer.call(@registry_name, {:register, name, module, config})
  end

  @doc """
  Unregisters a provider
  """
  @spec unregister(atom()) :: :ok
  def unregister(name) do
    GenServer.call(@registry_name, {:unregister, name})
  end

  @doc """
  Lists all registered providers
  """
  @spec list() :: [atom()]
  def list do
    GenServer.call(@registry_name, :list)
  end

  @doc """
  Gets provider configuration
  """
  @spec get_config(atom()) :: {:ok, map()} | {:error, :not_found}
  def get_config(name) do
    GenServer.call(@registry_name, {:get_config, name})
  end

  @doc """
  Gets provider module
  """
  @spec get_module(atom()) :: {:ok, module()} | {:error, :not_found}
  def get_module(name) do
    GenServer.call(@registry_name, {:get_module, name})
  end

  # GenServer callbacks

  @impl true
  def handle_call({:register, name, module, config}, _from, state) do
    new_state = %{
      state
      | providers: Map.put(state.providers, name, module),
        configs: Map.put(state.configs, name, config)
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:unregister, name}, _from, state) do
    new_state = %{
      state
      | providers: Map.delete(state.providers, name),
        configs: Map.delete(state.configs, name)
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:list, _from, state) do
    {:reply, Map.keys(state.providers), state}
  end

  @impl true
  def handle_call({:get_config, name}, _from, state) do
    case Map.fetch(state.configs, name) do
      {:ok, config} -> {:reply, {:ok, config}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:get_module, name}, _from, state) do
    case Map.fetch(state.providers, name) do
      {:ok, module} -> {:reply, {:ok, module}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end
end