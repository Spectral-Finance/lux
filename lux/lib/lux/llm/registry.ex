defmodule Lux.LLM.Registry do
  @moduledoc """
  An ETS-based dynamic registry for LLM providers in the Lux ecosystem.

  The Registry manages provider registration, discovery, and metadata lookup.
  Providers are stored in an ETS table with their metadata, capabilities, and
  configuration.

  ## Usage

      # Register a provider
      Lux.LLM.Registry.register(Lux.LLM.OpenAI)

      # List all providers
      Lux.LLM.Registry.list_providers()

      # Find a provider by capability
      Lux.LLM.Registry.find_by_capability(:vision)

      # Get metadata for a provider
      Lux.LLM.Registry.get_metadata(Lux.LLM.OpenAI)
  """

  @table_name :lux_llm_registry

  @doc """
  Start the Registry by creating the ETS table.

  Called during application startup.
  """
  @spec start_link(keyword()) :: {:ok, :ets.tid()}
  def start_link(_opts \\ []) do
    table = :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
    register_default_providers()
    {:ok, table}
  end

  @doc """
  Register a provider module in the registry.

  The provider must implement the `Lux.LLM.Provider` behaviour. Its metadata
  is automatically collected and stored.

  Returns `:ok` on success, or `{:error, reason}` if the module is not a valid provider.
  """
  @spec register(module()) :: :ok | {:error, String.t()}
  def register(provider_module) when is_atom(provider_module) do
    with :ok <- validate_provider(provider_module),
         metadata <- collect_metadata(provider_module) do
      :ets.insert(@table_name, {provider_module, metadata})
      :ok
    end
  end

  @doc """
  Unregister a provider from the registry.
  """
  @spec unregister(module()) :: :ok
  def unregister(provider_module) when is_atom(provider_module) do
    :ets.delete(@table_name, provider_module)
    :ok
  end

  @doc """
  Check if a provider is registered.
  """
  @spec registered?(module()) :: boolean()
  def registered?(provider_module) when is_atom(provider_module) do
    :ets.member(@table_name, provider_module)
  end

  @doc """
  List all registered provider modules.
  """
  @spec list_providers() :: [module()]
  def list_providers do
    @table_name
    |> :ets.tab2list()
    |> Enum.map(fn {module, _metadata} -> module end)
  end

  @doc """
  Get metadata for a registered provider.

  Returns `{:ok, metadata}` if found, `{:error, :not_found}` otherwise.
  """
  @spec get_metadata(module()) :: {:ok, Lux.LLM.Provider.provider_metadata()} | {:error, :not_found}
  def get_metadata(provider_module) when is_atom(provider_module) do
    case :ets.lookup(@table_name, provider_module) do
      [{^provider_module, metadata}] -> {:ok, metadata}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Find providers that support a given capability.

  Returns a list of provider modules.
  """
  @spec find_by_capability(Lux.LLM.Provider.capability()) :: [module()]
  def find_by_capability(capability) do
    @table_name
    |> :ets.tab2list()
    |> Enum.filter(fn {_module, metadata} ->
      capabilities = Map.get(metadata, :capabilities, [])
      capability in capabilities
    end)
    |> Enum.map(fn {module, _metadata} -> module end)
  end

  @doc """
  Find providers that support a given model.

  Returns a list of provider modules.
  """
  @spec find_by_model(String.t()) :: [module()]
  def find_by_model(model) when is_binary(model) do
    @table_name
    |> :ets.tab2list()
    |> Enum.filter(fn {_module, metadata} ->
      models = Map.get(metadata, :models, [])
      Enum.any?(models, fn m -> String.contains?(m, model) || m == model end)
    end)
    |> Enum.map(fn {module, _metadata} -> module end)
  end

  @doc """
  Get all registered providers with their metadata as a list.
  """
  @spec all_providers() :: [Lux.LLM.Provider.provider_metadata()]
  def all_providers do
    @table_name
    |> :ets.tab2list()
    |> Enum.map(fn {_module, metadata} -> metadata end)
  end

  @doc """
  Get the default provider module.

  Returns the first registered provider, or `Lux.LLM.OpenAI` as fallback.
  """
  @spec default_provider() :: module()
  def default_provider do
    case list_providers() do
      [first | _] -> first
      [] -> Lux.LLM.OpenAI
    end
  end

  @doc """
  Count the number of registered providers.
  """
  @spec count() :: non_neg_integer()
  def count do
    :ets.info(@table_name, :size)
  end

  @doc """
  Clear all registered providers from the registry.
  """
  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@table_name)
    :ok
  end

  @doc """
  Refresh metadata for all registered providers.

  Useful after application config changes.
  """
  @spec refresh() :: :ok
  def refresh do
    providers = list_providers()

    Enum.each(providers, fn provider ->
      metadata = collect_metadata(provider)
      :ets.insert(@table_name, {provider, metadata})
    end)

    :ok
  end

  # Private helpers

  defp validate_provider(module) do
    if Code.ensure_loaded?(module) && function_exported?(module, :call, 3) do
      :ok
    else
      {:error, "#{inspect(module)} does not implement Lux.LLM.Provider behaviour"}
    end
  end

  defp collect_metadata(module) do
    models = if function_exported?(module, :models, 0), do: module.models(), else: []
    capabilities = if function_exported?(module, :capabilities, 0), do: module.capabilities(), else: []
    default_config = if function_exported?(module, :default_config, 0), do: module.default_config(), else: nil

    metadata =
      if function_exported?(module, :metadata, 0) do
        module.metadata()
      else
        %{}
      end

    Map.merge(metadata, %{
      name: metadata[:name] || module |> Module.split() |> List.last(),
      module: module,
      models: metadata[:models] || models,
      capabilities: metadata[:capabilities] || capabilities,
      default_config: default_config,
      registered_at: DateTime.utc_now()
    })
  end

  defp register_default_providers do
    providers = [
      Lux.LLM.OpenAI,
      Lux.LLM.Anthropic,
      Lux.LLM.Mira,
      Lux.LLM.TogetherAI
    ]

    Enum.each(providers, fn provider ->
      if Code.ensure_loaded?(provider) do
        register(provider)
      end
    end)
  end
end
