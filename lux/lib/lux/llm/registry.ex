defmodule Lux.LLM.Registry do
  @moduledoc """
  Registry for managing LLM providers.

  The registry maintains a mapping of provider names to their modules and metadata.
  It supports both static registration (compile-time defaults) and dynamic registration
  at runtime.

  ## Built-in Providers

  The following providers are registered by default:

  - `:openai` → `Lux.LLM.OpenAI`
  - `:anthropic` → `Lux.LLM.Anthropic`
  - `:together_ai` → `Lux.LLM.TogetherAI`
  - `:mira` → `Lux.LLM.Mira`

  ## Usage

      # Register a custom provider
      Lux.LLM.Registry.register(:my_provider, MyProvider)

      # Look up a provider module
      {:ok, module} = Lux.LLM.Registry.get(:openai)

      # List all registered providers
      providers = Lux.LLM.Registry.list()

      # Get provider info with capabilities
      {:ok, info} = Lux.LLM.Registry.provider_info(:openai)
  """

  use GenServer

  require Logger

  @table_name :lux_llm_registry
  @health_table :lux_llm_provider_health

  # Built-in provider mappings
  @default_providers %{
    openai: Lux.LLM.OpenAI,
    anthropic: Lux.LLM.Anthropic,
    together_ai: Lux.LLM.TogetherAI,
    mira: Lux.LLM.Mira
  }

  # ── Client API ──────────────────────────────────────────────────────

  @doc """
  Starts the registry process.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Registers a provider module under the given name.

  ## Examples

      iex> Lux.LLM.Registry.register(:openai, Lux.LLM.OpenAI)
      :ok

      iex> Lux.LLM.Registry.register(:custom, MyCustomProvider)
      :ok
  """
  @spec register(atom(), module(), keyword()) :: :ok
  def register(name, module, opts \\ []) when is_atom(name) and is_atom(module) do
    priority = Keyword.get(opts, :priority, 50)
    :ets.insert(@table_name, {name, module, priority})
    :ok
  end

  @doc """
  Unregisters a provider by name.
  """
  @spec unregister(atom()) :: :ok
  def unregister(name) when is_atom(name) do
    :ets.delete(@table_name, name)
    :ok
  end

  @doc """
  Gets the provider module for the given name.

  Returns `{:ok, module}` if found, `:error` otherwise.
  Also resolves module atoms directly (e.g., `Lux.LLM.OpenAI`).
  """
  @spec get(atom()) :: {:ok, module()} | :error
  def get(name) when is_atom(name) do
    case :ets.lookup(@table_name, name) do
      [{^name, module, _priority}] ->
        {:ok, module}

      [] ->
        # Check if it's already a module
        if Lux.LLM.Provider.provider?(name) do
          {:ok, name}
        else
          :error
        end
    end
  end

  @doc """
  Gets the provider module or raises if not found.
  """
  @spec get!(atom()) :: module()
  def get!(name) do
    case get(name) do
      {:ok, module} -> module
      :error -> raise "LLM provider #{inspect(name)} not found in registry"
    end
  end

  @doc """
  Lists all registered providers as `[{name, module, priority}]`.
  """
  @spec list() :: [{atom(), module(), integer()}]
  def list do
    :ets.tab2list(@table_name)
  rescue
    ArgumentError -> []
  end

  @doc """
  Lists all registered provider names.
  """
  @spec list_names() :: [atom()]
  def list_names do
    list() |> Enum.map(fn {name, _mod, _prio} -> name end)
  end

  @doc """
  Returns provider info (capabilities, models, pricing) if the provider
  implements `provider_info/0`.
  """
  @spec provider_info(atom()) :: {:ok, Lux.LLM.Provider.Info.t()} | :error
  def provider_info(name) do
    with {:ok, module} <- get(name) do
      if function_exported?(module, :provider_info, 0) do
        {:ok, module.provider_info()}
      else
        {:ok,
         %Lux.LLM.Provider.Info{
           name: name,
           display_name: to_string(name),
           module: module
         }}
      end
    end
  end

  @doc """
  Reports a provider's health status (called after each request).
  """
  @spec report_health(atom(), :ok | :error, non_neg_integer()) :: :ok
  def report_health(provider_name, status, latency_ms) do
    now = System.system_time(:millisecond)

    case :ets.lookup(@health_table, provider_name) do
      [{^provider_name, health}] ->
        updated =
          health
          |> update_health(status, latency_ms, now)

        :ets.insert(@health_table, {provider_name, updated})

      [] ->
        health = new_health(status, latency_ms, now)
        :ets.insert(@health_table, {provider_name, health})
    end

    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc """
  Gets the health status of a provider.
  """
  @spec health(atom()) :: map() | nil
  def health(provider_name) do
    case :ets.lookup(@health_table, provider_name) do
      [{^provider_name, health}] -> health
      [] -> nil
    end
  rescue
    ArgumentError -> nil
  end

  @doc """
  Returns all providers sorted by health score (best first).
  Useful for automatic selection.
  """
  @spec healthy_providers() :: [{atom(), module(), float()}]
  def healthy_providers do
    list()
    |> Enum.map(fn {name, module, _priority} ->
      score = health_score(name)
      {name, module, score}
    end)
    |> Enum.sort_by(fn {_name, _mod, score} -> score end, :desc)
  end

  @doc """
  Returns a health score between 0.0 and 1.0 for the provider.
  Considers error rate and average latency.
  """
  @spec health_score(atom()) :: float()
  def health_score(provider_name) do
    case health(provider_name) do
      nil ->
        # Unknown health = neutral score
        0.5

      %{total_requests: 0} ->
        0.5

      %{total_requests: total, error_count: errors, avg_latency_ms: avg_lat} ->
        error_rate = errors / max(total, 1)
        # Score: 70% from success rate, 30% from latency (inverse, capped)
        success_score = 1.0 - error_rate
        latency_score = max(0.0, 1.0 - avg_lat / 30_000.0)
        success_score * 0.7 + latency_score * 0.3
    end
  end

  # ── GenServer Callbacks ─────────────────────────────────────────────

  @impl true
  def init(_opts) do
    table = :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
    _health = :ets.new(@health_table, [:named_table, :set, :public, read_concurrency: true])

    # Register default providers
    for {name, module} <- @default_providers do
      :ets.insert(table, {name, module, default_priority(name)})
    end

    {:ok, %{table: table}}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ── Private ─────────────────────────────────────────────────────────

  defp default_priority(:openai), do: 90
  defp default_priority(:anthropic), do: 85
  defp default_priority(:together_ai), do: 70
  defp default_priority(:mira), do: 60
  defp default_priority(_), do: 50

  defp new_health(status, latency_ms, now) do
    %{
      total_requests: 1,
      error_count: if(status == :error, do: 1, else: 0),
      avg_latency_ms: latency_ms * 1.0,
      last_request_at: now,
      last_error_at: if(status == :error, do: now, else: nil),
      consecutive_errors: if(status == :error, do: 1, else: 0)
    }
  end

  defp update_health(health, status, latency_ms, now) do
    total = health.total_requests + 1
    # Exponential moving average for latency
    alpha = 0.3
    new_avg = health.avg_latency_ms * (1 - alpha) + latency_ms * alpha

    %{
      health
      | total_requests: total,
        error_count: health.error_count + if(status == :error, do: 1, else: 0),
        avg_latency_ms: new_avg,
        last_request_at: now,
        last_error_at: if(status == :error, do: now, else: health.last_error_at),
        consecutive_errors:
          if(status == :error,
            do: health.consecutive_errors + 1,
            else: 0
          )
    }
  end
end
