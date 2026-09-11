defmodule Lux.LLM.ProviderRegistry do
  @moduledoc """
  GenServer process for managing registered LLM providers and model configurations dynamically.
  """

  use GenServer

  alias Lux.LLM.ModelConfig
  alias Lux.LLM.ProviderConfig

  @type registry_state :: %{
          providers: %{atom() => ProviderConfig.t()}
        }

  # --- Public API ---

  @doc """
  Starts the ProviderRegistry GenServer.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Registers a provider module or ProviderConfig struct.
  """
  def register_provider(provider, opts \\ [])

  def register_provider(%ProviderConfig{} = config, opts) do
    name = Keyword.get(opts, :registry_name, __MODULE__)
    GenServer.call(name, {:register_provider, config})
  end

  def register_provider(module, opts) when is_atom(module) do
    name = Keyword.get(opts, :registry_name, __MODULE__)

    id =
      Keyword.get(opts, :id) ||
        (function_exported?(module, :id, 0) && module.id()) ||
        module

    models =
      Keyword.get(opts, :models) ||
        (function_exported?(module, :models, 0) && module.models()) ||
        []

    config = %ProviderConfig{
      id: id,
      module: module,
      api_key: Keyword.get(opts, :api_key),
      endpoint: Keyword.get(opts, :endpoint),
      models: models,
      status: Keyword.get(opts, :status, :active)
    }

    GenServer.call(name, {:register_provider, config})
  end

  @doc """
  Unregisters a provider by its atom ID.
  """
  def unregister_provider(provider_id, opts \\ []) when is_atom(provider_id) do
    name = Keyword.get(opts, :registry_name, __MODULE__)
    GenServer.call(name, {:unregister_provider, provider_id})
  end

  @doc """
  Normalizes provider ID atoms to their canonical forms (e.g. :open_router -> :openrouter, :together_ai -> :together).
  """
  def normalize_provider_id(:open_router), do: :openrouter
  def normalize_provider_id(:together_ai), do: :together
  def normalize_provider_id(id), do: id

  @doc """
  Retrieves a registered provider config by ID.
  """
  def get_provider(provider_id, opts \\ []) when is_atom(provider_id) do
    name = Keyword.get(opts, :registry_name, __MODULE__)
    canonical_id = normalize_provider_id(provider_id)

    case GenServer.whereis(name) do
      nil ->
        {:error, :not_found}

      _pid ->
        try do
          GenServer.call(name, {:get_provider, canonical_id})
        catch
          :exit, _ -> {:error, :not_found}
        end
    end
  end

  @doc """
  Lists all registered providers.
  """
  def list_providers(opts \\ []) do
    name = Keyword.get(opts, :registry_name, __MODULE__)

    case GenServer.whereis(name) do
      nil ->
        []

      _pid ->
        try do
          GenServer.call(name, :list_providers)
        catch
          :exit, _ -> []
        end
    end
  end

  @doc """
  Lists models across all registered providers, with optional filtering.
  Options:
  - `:provider_id` - filter by specific provider atom ID
  - `:status` - filter providers by status (e.g. `:active`)
  - `:capabilities` - list of required capability atoms (e.g. `[:tools]`)
  """
  def list_models(filter_opts \\ []) do
    name = Keyword.get(filter_opts, :registry_name, __MODULE__)

    normalized_opts =
      case Keyword.get(filter_opts, :provider_id) do
        nil -> filter_opts
        prov_id -> Keyword.put(filter_opts, :provider_id, normalize_provider_id(prov_id))
      end

    case GenServer.whereis(name) do
      nil ->
        []

      _pid ->
        try do
          GenServer.call(name, {:list_models, normalized_opts})
        catch
          :exit, _ -> []
        end
    end
  end

  @doc """
  Updates the status of a registered provider.
  """
  def update_provider_status(provider_id, status, opts \\ []) when is_atom(provider_id) do
    name = Keyword.get(opts, :registry_name, __MODULE__)
    GenServer.call(name, {:update_provider_status, provider_id, status})
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(opts) do
    initial_providers = Keyword.get(opts, :providers, default_providers())
    providers_map = Enum.reduce(initial_providers, %{}, &init_provider_entry/2)

    {:ok, %{providers: providers_map}}
  end

  defp init_provider_entry(%ProviderConfig{} = config, acc) do
    Map.put(acc, config.id, config)
  end

  defp init_provider_entry(module, acc) when is_atom(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :id, 0) do
      models = if function_exported?(module, :models, 0), do: module.models(), else: []

      config = %ProviderConfig{
        id: module.id(),
        module: module,
        models: models,
        status: :active
      }

      Map.put(acc, config.id, config)
    else
      acc
    end
  end

  @impl true
  def handle_call({:register_provider, %ProviderConfig{} = config}, _from, state) do
    new_providers = Map.put(state.providers, config.id, config)
    {:reply, {:ok, config}, %{state | providers: new_providers}}
  end

  @impl true
  def handle_call({:unregister_provider, provider_id}, _from, state) do
    case Map.fetch(state.providers, provider_id) do
      {:ok, config} ->
        new_providers = Map.delete(state.providers, provider_id)
        {:reply, {:ok, config}, %{state | providers: new_providers}}

      :error ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:get_provider, provider_id}, _from, state) do
    case Map.fetch(state.providers, provider_id) do
      {:ok, config} -> {:reply, {:ok, config}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:list_providers, _from, state) do
    providers = Map.values(state.providers)
    {:reply, providers, state}
  end

  @impl true
  def handle_call({:list_models, filter_opts}, _from, state) do
    target_provider = Keyword.get(filter_opts, :provider_id)
    target_status = Keyword.get(filter_opts, :status)
    required_caps = Keyword.get(filter_opts, :capabilities, [])

    models =
      state.providers
      |> Map.values()
      |> Enum.filter(fn config ->
        (is_nil(target_provider) or config.id == target_provider) and
          (is_nil(target_status) or config.status == target_status)
      end)
      |> Enum.flat_map(fn config -> config.models end)
      |> Enum.filter(fn %ModelConfig{} = model ->
        Enum.all?(required_caps, fn cap -> cap in model.capabilities end)
      end)

    {:reply, models, state}
  end

  @impl true
  def handle_call({:update_provider_status, provider_id, status}, _from, state) do
    case Map.fetch(state.providers, provider_id) do
      {:ok, config} ->
        updated_config = %{config | status: status}
        new_providers = Map.put(state.providers, provider_id, updated_config)
        {:reply, {:ok, updated_config}, %{state | providers: new_providers}}

      :error ->
        {:reply, {:error, :not_found}, state}
    end
  end

  # --- Helper Functions ---

  defp default_providers do
    [
      Lux.LLM.OpenAI,
      Lux.LLM.Gemini,
      Lux.LLM.Anthropic,
      Lux.LLM.OpenRouter,
      Lux.LLM.TogetherAI,
      Lux.LLM.Mira
    ]
  end
end
