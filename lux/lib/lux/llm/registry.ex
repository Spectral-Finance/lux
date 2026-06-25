defmodule Lux.LLM.Registry do
  @moduledoc """
  Registry for managing LLM providers.
  Provides registration, lookup, and discovery of providers.
  """

  use GenServer

  alias Lux.LLM.Provider

  @type provider_name :: atom()
  @type provider_entry :: {provider_name(), module(), map()}

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Registers a new provider.
  """
  @spec register(provider_name(), module(), map()) :: :ok
  def register(name, module, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:register, name, module, metadata})
  end

  @doc """
  Unregisters a provider.
  """
  @spec unregister(provider_name()) :: :ok
  def unregister(name) do
    GenServer.call(__MODULE__, {:unregister, name})
  end

  @doc """
  Gets a provider by name.
  """
  @spec get(provider_name()) :: module() | nil
  def get(name) do
    GenServer.call(__MODULE__, {:get, name})
  end

  @doc """
  Lists all registered providers.
  """
  @spec list_providers() :: [{provider_name(), module(), map()}]
  def list_providers do
    GenServer.call(__MODULE__, :list)
  end

  @doc """
  Finds a provider that supports the given model.
  """
  @spec find_by_model(String.t()) :: module() | nil
  def find_by_model(model) do
    GenServer.call(__MODULE__, {:find_by_model, model})
  end

  # Server Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:register, name, module, metadata}, _from, state) do
    {:reply, :ok, Map.put(state, name, {module, metadata})}
  end

  @impl true
  def handle_call({:unregister, name}, _from, state) do
    {:reply, :ok, Map.delete(state, name)}
  end

  @impl true
  def handle_call({:get, name}, _from, state) do
    {:reply, get_in(state, [name, Access.elem(0)]), state}
  end

  @impl true
  def handle_call(:list, _from, state) do
    providers = Enum.map(state, fn {name, {mod, meta}} -> {name, mod, meta} end)
    {:reply, providers, state}
  end

  @impl true
  def handle_call({:find_by_model, model}, _from, state) do
    result = Enum.find(state, fn {_, {mod, _}} -> mod.supports_model?(model) end)
    {:reply, elem(result, 1) |> elem(0), state}
  end
end