defmodule Lux.LLM.ProviderRegistry do
  @moduledoc """
  Dynamic registry and circuit-breaker health manager for LLM providers.

  Stores registered providers (`%Lux.LLM.Provider.Spec{}`) in an ETS table
  (`:lux_llm_provider_registry`) and seeds the built-in providers (`:openai`,
  `:anthropic`, `:together_ai`, `:mira`) automatically on first access.
  """

  alias Lux.LLM.Provider
  alias Lux.LLM.Provider.ModelInfo
  alias Lux.LLM.Provider.Spec

  @table :lux_llm_provider_registry

  @doc """
  Ensures the ETS registry table is initialized and seeded with default providers.
  """
  @spec ensure_started() :: :ok
  def ensure_started do
    case :ets.whereis(@table) do
      :undefined ->
        try do
          :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
          seed_defaults()
        rescue
          ArgumentError -> :ok
        end

      _tid ->
        :ok
    end
  end

  @doc """
  Resets the registry to its initial default provider specifications.
  """
  @spec reset!() :: :ok
  def reset! do
    ensure_started()
    :ets.delete_all_objects(@table)
    seed_defaults()
  end

  @doc """
  Registers or updates a provider specification in the registry.
  """
  @spec register_provider(atom(), Spec.t() | map()) :: {:ok, Spec.t()}
  def register_provider(id, %Spec{} = spec) when is_atom(id) do
    ensure_started()
    normalized = normalize_spec(%{spec | id: id})
    :ets.insert(@table, {id, normalized})
    {:ok, normalized}
  end

  def register_provider(id, attrs) when is_atom(id) and is_map(attrs) do
    ensure_started()

    models =
      attrs
      |> Map.get(:models, [])
      |> Enum.map(fn
        %ModelInfo{} = model -> %{model | provider: id}
        map when is_map(map) -> struct(ModelInfo, Map.put(map, :provider, id))
      end)

    spec =
      Spec
      |> struct(Map.put(attrs, :id, id))
      |> Map.put(:models, models)

    :ets.insert(@table, {id, spec})
    {:ok, spec}
  end

  @doc """
  Removes a provider from the registry.
  """
  @spec unregister_provider(atom()) :: :ok
  def unregister_provider(id) when is_atom(id) do
    ensure_started()
    :ets.delete(@table, id)
    :ok
  end

  @doc """
  Fetches a provider specification by its identifier.
  """
  @spec get_provider(atom()) :: {:ok, Spec.t()} | {:error, :not_found}
  def get_provider(id) when is_atom(id) do
    ensure_started()

    case :ets.lookup(@table, id) do
      [{^id, spec}] -> {:ok, spec}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Lists all registered providers sorted by priority descending.

  ## Options
  - `:only_enabled` (boolean, default `false`) - filter to enabled providers
  - `:only_healthy` (boolean, default `false`) - filter to healthy providers
  """
  @spec list_providers(keyword()) :: [Spec.t()]
  def list_providers(opts \\ []) do
    ensure_started()
    only_enabled = Keyword.get(opts, :only_enabled, false)
    only_healthy = Keyword.get(opts, :only_healthy, false)

    @table
    |> :ets.tab2list()
    |> Enum.map(fn {_id, spec} -> spec end)
    |> Enum.filter(fn spec ->
      enabled_ok = not only_enabled or spec.enabled
      healthy_ok = not only_healthy or spec_healthy?(spec)
      enabled_ok and healthy_ok
    end)
    |> Enum.sort_by(& &1.priority, :desc)
  end

  @doc """
  Enables a provider and resets its failure counter.
  """
  @spec enable_provider(atom()) :: :ok | {:error, :not_found}
  def enable_provider(id) when is_atom(id) do
    update_provider(id, fn spec ->
      %{spec | enabled: true, failure_count: 0, last_failure_at: nil}
    end)
  end

  @doc """
  Disables a provider from automatic routing and fallback selection.
  """
  @spec disable_provider(atom()) :: :ok | {:error, :not_found}
  def disable_provider(id) when is_atom(id) do
    update_provider(id, fn spec -> %{spec | enabled: false} end)
  end

  @doc """
  Records a successful call for a provider, resetting its circuit breaker state.
  """
  @spec mark_success(atom()) :: :ok | {:error, :not_found}
  def mark_success(id) when is_atom(id) do
    update_provider(id, fn spec ->
      %{spec | failure_count: 0, last_failure_at: nil}
    end)
  end

  @doc """
  Records a failed call for a provider, incrementing its failure count.
  """
  @spec mark_failure(atom(), term()) :: :ok | {:error, :not_found}
  def mark_failure(id, _reason \\ nil) when is_atom(id) do
    now = System.monotonic_time(:millisecond)

    update_provider(id, fn spec ->
      %{spec | failure_count: spec.failure_count + 1, last_failure_at: now}
    end)
  end

  @doc """
  Returns true if the provider is enabled and its circuit breaker is closed
  or half-open after cooldown.
  """
  @spec healthy?(atom()) :: boolean()
  def healthy?(id) when is_atom(id) do
    case get_provider(id) do
      {:ok, spec} -> spec_healthy?(spec)
      {:error, :not_found} -> false
    end
  end

  @doc """
  Finds a model descriptor across registered providers.
  """
  @spec find_model(atom(), String.t()) :: {:ok, ModelInfo.t()} | {:error, :not_found}
  def find_model(provider_id, model_name) when is_atom(provider_id) and is_binary(model_name) do
    with {:ok, spec} <- get_provider(provider_id),
         %ModelInfo{} = info <- Enum.find(spec.models, &(&1.name == model_name)) do
      {:ok, info}
    else
      _ -> {:error, :not_found}
    end
  end

  defp spec_healthy?(%Spec{enabled: false}), do: false

  defp spec_healthy?(%Spec{
         failure_count: failures,
         circuit_breaker_threshold: threshold,
         last_failure_at: last_failure_at,
         circuit_breaker_cooldown_ms: cooldown_ms
       }) do
    cond do
      failures < threshold ->
        true

      is_nil(last_failure_at) ->
        true

      System.monotonic_time(:millisecond) - last_failure_at >= cooldown_ms ->
        true

      true ->
        false
    end
  end

  defp update_provider(id, fun) do
    case get_provider(id) do
      {:ok, spec} ->
        :ets.insert(@table, {id, fun.(spec)})
        :ok

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  defp normalize_spec(%Spec{id: id, models: models} = spec) do
    normalized_models =
      Enum.map(models, fn
        %ModelInfo{} = model -> %{model | provider: id}
        map when is_map(map) -> struct(ModelInfo, Map.put(map, :provider, id))
      end)

    %{spec | models: normalized_models}
  end

  defp seed_defaults do
    Enum.each(Provider.default_provider_specs(), fn spec ->
      :ets.insert(@table, {spec.id, spec})
    end)

    :ok
  end
end
