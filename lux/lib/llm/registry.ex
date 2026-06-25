defmodule Lux.LLM.Registry do
  @moduledoc """
  Registry for LLM providers with automatic selection and fallback handling
  """

  use GenServer

  @default_config %{
    providers: %{},
    default_provider: nil,
    fallback_chain: [],
    monitoring: true
  }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, @default_config}
  end

  @doc """
  Registers a new LLM provider
  """
  @spec register_provider(atom(), module(), map()) :: :ok
  def register_provider(name, provider_module, config \\ %{}) do
    GenServer.call(__MODULE__, {:register_provider, name, provider_module, config})
  end

  @doc """
  Sets the default provider
  """
  @spec set_default(atom()) :: :ok
  def set_default(provider_name) do
    GenServer.call(__MODULE__, {:set_default, provider_name})
  end

  @doc """
  Sets the fallback chain for providers
  """
  @spec set_fallback_chain([atom()]) :: :ok
  def set_fallback_chain(chain) do
    GenServer.call(__MODULE__, {:set_fallback_chain, chain})
  end

  @doc """
  Gets all registered providers
  """
  @spec get_providers() :: map()
  def get_providers() do
    GenServer.call(__MODULE__, :get_providers)
  end

  @doc """
  Generates text using the best available provider
  """
  @spec generate(String.t(), keyword()) :: {:ok, String.t()} | {:error, any()}
  def generate(prompt, opts \\ []) do
    GenServer.call(__MODULE__, {:generate, prompt, opts})
  end

  @impl true
  def handle_call({:register_provider, name, provider_module, config}, _from, state) do
    providers = Map.put(state.providers, name, %{module: provider_module, config: config})
    {:reply, :ok, %{state | providers: providers}}
  end

  @impl true
  def handle_call({:set_default, provider_name}, _from, state) do
    {:reply, :ok, %{state | default_provider: provider_name}}
  end

  @impl true
  def handle_call({:set_fallback_chain, chain}, _from, state) do
    {:reply, :ok, %{state | fallback_chain: chain}}
  end

  @impl true
  def handle_call(:get_providers, _from, state) do
    {:reply, state.providers, state}
  end

  @impl true
  def handle_call({:generate, prompt, opts}, _from, state) do
    result = do_generate(prompt, opts, state)
    {:reply, result, state}
  end

  defp do_generate(prompt, opts, state) do
    # Implementation for provider selection and fallback logic
    # This would try the default provider first, then fall back through the chain
    {:error, :not_implemented}
  end
end