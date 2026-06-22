# Fix for Issue #99: LLM Provider Abstraction Layer $600

defmodule Lux.LLM.Provider.Registry do
  @moduledoc """
  Registry for managing LLM providers.
  
  Provides a centralized system for registering, discovering, and managing
  LLM providers. Supports dynamic provider registration and configuration.
  """

  use GenServer
  require Logger

  @table_name :lux_llm_providers

  defstruct providers: %{}, models: %{}, default_provider: nil

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a new provider with the given configuration.
  """
  @spec register(atom(), module(), keyword()) :: :ok | {:error, term()}
  def register(name, module, config \\ []) do
    GenServer.call(__MODULE__, {:register, name, module, config})
  end

  @doc """
  Unregisters a provider.
  """
  @spec unregister(atom()) :: :ok
  def unregister(name) do
    GenServer.call(__MODULE__, {:unregister, name})
  end

  @doc """
  Gets a registered provider by name.
  """
  @spec get(atom()) :: {:ok, {module(), keyword()}} | {:error, :not_found}
  def get(name) do
    case :ets.lookup(@table_name, {:provider, name}) do
      [{_, module, config}] -> {:ok, {module, config}}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Lists all registered providers.
  """
  @spec list() :: [{atom(), module(), keyword()}]
  def list do
    :ets.match(@table_name, {{:provider, :"$1"}, :"$2", :"$3"})
    |> Enum.map(fn [name, module, config] -> {name, module, config} end)
  end

  @doc """
  Gets the default provider.
  """
  @spec get_default() :: {:ok, atom()} | {:error, :no_default}
  def get_default do
    GenServer.call(__MODULE__, :get_default)
  end

  @doc """
  Sets the default provider.
  """
  @spec set_default(atom()) :: :ok | {:error, :not_found}
  def set_default(name) do
    GenServer.call(__MODULE__, {:set_default, name})
  end

  @doc """
  Finds a provider that supports the given model.
  """
  @spec find_provider_for_model(String.t()) :: {:ok, atom()} | {:error, :not_found}
  def find_provider_for_model(model_id) do
    case :ets.lookup(@table_name, {:model, model_id}) do
      [{_, provider}] -> {:ok, provider}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Registers model to provider mapping.
  """
  @spec register_model(String.t(), atom()) :: :ok
  def register_model(model_id, provider) do
    GenServer.call(__MODULE__, {:register_model, model_id, provider})
  end

  @doc """
  Lists all registered models.
  """
  @spec list_models() :: [{String.t(), atom()}]
  def list_models do
    :ets.match(@table_name, {{:model, :"$1"}, :"$2"})
    |> Enum.map(fn [model_id, provider] -> {model_id, provider} end)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    table = :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
    
    state = %__MODULE__{
      providers: %{},
      models: %{},
      default_provider: Keyword.get(opts, :default_provider)
    }

    # Register default providers if configured
    if Keyword.get(opts, :register_defaults, true) do
      register_default_providers()
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:register, name, module, config}, _from, state) do
    case module.validate_config(config) do
      :ok ->
        :ets.insert(@table_name, {{:provider, name}, module, config})
        
        # Register all models from this provider
        case module.list_models(config) do
          {:ok, models} ->
            Enum.each(models, fn model ->
              :ets.insert(@table_name, {{:model, model.id}, name})
            end)
          _ -> :ok
        end

        new_state = %{state | providers: Map.put(state.providers, name, {module, config})}
        
        # Set as default if it's the first provider
        new_state = if map_size(state.providers) == 0 and is_nil(state.default_provider) do
          %{new_state | default_provider: name}
        else
          new_state
        end

        Logger.info("Registered LLM provider: #{name}")
        {:reply, :ok, new_state}
      
      {:error, reason} ->
        {:reply, {:error, {:invalid_config, reason}}, state}
    end
  end

  @impl true
  def handle_call({:unregister, name}, _from, state) do
    :ets.delete(@table_name, {:provider, name})
    
    # Remove model mappings for this provider
    :ets.match(@table_name, {{:model, :"$1"}, name})
    |> Enum.each(fn [model_id] ->
      :ets.delete(@table_name, {:model, model_id})
    end)

    new_state = %{state | providers: Map.delete(state.providers, name)}
    
    # Clear default if it was this provider
    new_state = if state.default_provider == name do
      %{new_state | default_provider: nil}
    else
      new_state
    end

    Logger.info("Unregistered LLM provider: #{name}")
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_default, _from, state) do
    case state.default_provider do
      nil -> {:reply, {:error, :no_default}, state}
      provider -> {:reply, {:ok, provider}, state}
    end
  end

  @impl true
  def handle_call({:set_default, name}, _from, state) do
    case :ets.lookup(@table_name, {:provider, name}) do
      [{_, _, _}] ->
        {:reply, :ok, %{state | default_provider: name}}
      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:register_model, model_id, provider}, _from, state) do
    :ets.insert(@table_name, {{:model, model_id}, provider})
    {:reply, :ok, state}
  end

  # Private Functions

  defp register_default_providers do
    providers = [
      {:openai, Lux.LLM.Provider.OpenAI},
      {:anthropic, Lux.LLM.Provider.Anthropic},
      {:google, Lux.LLM.Provider.Google},
      {:ollama, Lux.LLM.Provider.Ollama}
    ]

    Enum.each(providers, fn {name, module} ->
      config = Application.get_env(:lux, [:llm, name], [])
      if config != [] and Keyword.get(config, :enabled, true) do
        case module.validate_config(config) do
          :ok ->
            :ets.insert(@table_name, {{:provider, name}, module, config})
            Logger.debug("Auto-registered LLM provider: #{name}")
          {:error, _} ->
            Logger.debug("Skipping provider #{name}: invalid config")
        end
      end
    end)
  end
end