defmodule Lux.LLM.ProviderRegistry do
  @moduledoc """
  GenServer-based registry for managing LLM providers.

  Handles registration, deregistration, selection, and health tracking
  of all available providers. Supports priority-based and cost-based
  provider selection with automatic fallback.

  ## Starting

  Add to your supervision tree:

      children = [
        {Lux.LLM.ProviderRegistry, []}
      ]

  ## Usage

      # Register a provider
      Lux.LLM.ProviderRegistry.register(:openai, Lux.LLM.OpenAI,
        name: "OpenAI", priority: 10, models: ["gpt-4", "gpt-4o-mini"])

      # Get best provider for a model
      Lux.LLM.ProviderRegistry.select_for_model("gpt-4")

      # Call with automatic fallback
      Lux.LLM.ProviderRegistry.call_with_fallback("prompt", [], "gpt-4")
  """

  use GenServer

  alias Lux.LLM.Provider

  @registry_table :lux_llm_providers
  @health_table :lux_llm_provider_health

  # Client API

  @doc """
  Starts the registry.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Register a provider module with the given ID and options.
  """
  @spec register(Provider.provider_id(), module(), keyword()) :: :ok | {:error, term()}
  def register(provider_id, module, opts \\ []) do
    GenServer.call(__MODULE__, {:register, provider_id, module, opts})
  end

  @doc """
  Deregister a provider by ID.
  """
  @spec deregister(Provider.provider_id()) :: :ok
  def deregister(provider_id) do
    GenServer.call(__MODULE__, {:deregister, provider_id})
  end

  @doc """
  List all registered providers.
  """
  @spec list_providers() :: [Provider.t()]
  def list_providers do
    GenServer.call(__MODULE__, :list_providers)
  end

  @doc """
  Get a specific provider by ID.
  """
  @spec get_provider(Provider.provider_id()) :: Provider.t() | nil
  def get_provider(provider_id) do
    GenServer.call(__MODULE__, {:get_provider, provider_id})
  end

  @doc """
  Select the best provider for a given model name.

  Returns the provider with the highest priority that supports the model
  and is currently enabled and available.
  """
  @spec select_for_model(String.t()) :: Provider.t() | nil
  def select_for_model(model) do
    GenServer.call(__MODULE__, {:select_for_model, model})
  end

  @doc """
  Select the cheapest provider that supports a given model.
  """
  @spec select_cheapest(String.t(), pos_integer(), pos_integer()) :: Provider.t() | nil
  def select_cheapest(model, input_tokens, output_tokens) do
    GenServer.call(__MODULE__, {:select_cheapest, model, input_tokens, output_tokens})
  end

  @doc """
  Call a provider with automatic fallback to the next available provider.

  If the primary provider fails, tries the next provider in priority order.
  """
  @spec call_with_fallback(String.t(), list(), String.t() | nil, keyword()) ::
          {:ok, Lux.LLM.Response.t()} | {:error, String.t()}
  def call_with_fallback(prompt, tools, model \\ nil, opts \\ []) do
    GenServer.call(__MODULE__, {:call_with_fallback, prompt, tools, model, opts}, 120_000)
  end

  @doc """
  Record a health event for a provider (success or failure).
  """
  @spec record_health(Provider.provider_id(), :ok | :error, term()) :: :ok
  def record_health(provider_id, status, metadata \\ nil) do
    GenServer.cast(__MODULE__, {:record_health, provider_id, status, metadata})
  end

  @doc """
  Get health stats for a provider.
  """
  @spec health(Provider.provider_id()) :: map() | nil
  def health(provider_id) do
    GenServer.call(__MODULE__, {:health, provider_id})
  end

  @doc """
  Enable a provider.
  """
  @spec enable(Provider.provider_id()) :: :ok | {:error, :not_found}
  def enable(provider_id) do
    GenServer.call(__MODULE__, {:set_enabled, provider_id, true})
  end

  @doc """
  Disable a provider.
  """
  @spec disable(Provider.provider_id()) :: :ok | {:error, :not_found}
  def disable(provider_id) do
    GenServer.call(__MODULE__, {:set_enabled, provider_id, false})
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    state = %{
      providers: %{},
      health: %{}
    }

    # Register built-in providers from app config
    register_builtin_providers(state)
  end

  @impl true
  def handle_call({:register, provider_id, module, opts}, _from, state) do
    provider = Provider.new([
      id: provider_id,
      module: module,
      name: Keyword.get(opts, :name, Atom.to_string(provider_id)),
      models: Keyword.get(opts, :models, []),
      priority: Keyword.get(opts, :priority, 0),
      enabled: Keyword.get(opts, :enabled, true),
      config: Keyword.get(opts, :config, %{})
    ])

    # Verify the module implements the behaviour
    if Provider.implements?(module) do
      new_providers = Map.put(state.providers, provider_id, provider)
      {:reply, :ok, %{state | providers: new_providers}}
    else
      {:reply, {:error, :invalid_provider_module}, state}
    end
  end

  def handle_call({:deregister, provider_id}, _from, state) do
    new_providers = Map.delete(state.providers, provider_id)
    new_health = Map.delete(state.health, provider_id)
    {:reply, :ok, %{state | providers: new_providers, health: new_health}}
  end

  def handle_call(:list_providers, _from, state) do
    {:reply, Map.values(state.providers), state}
  end

  def handle_call({:get_provider, provider_id}, _from, state) do
    {:reply, Map.get(state.providers, provider_id), state}
  end

  def handle_call({:select_for_model, model}, _from, state) do
    result =
      state.providers
      |> Map.values()
      |> Enum.filter(&provider_supports_model?(&1, model))
      |> Enum.filter(& &1.enabled)
      |> Enum.sort_by(& &1.priority, :desc)
      |> List.first()

    {:reply, result, state}
  end

  def handle_call({:select_cheapest, model, input_tokens, output_tokens}, _from, state) do
    result =
      state.providers
      |> Map.values()
      |> Enum.filter(&provider_supports_model?(&1, model))
      |> Enum.filter(& &1.enabled)
      |> Enum.map(fn provider ->
        cost = provider.module.estimate_cost(model, input_tokens, output_tokens)
        {cost, provider}
      end)
      |> Enum.sort_by(&elem(&1, 0))
      |> List.first()

    {:reply, if(result, do: elem(result, 1), else: nil), state}
  end

  def handle_call({:call_with_fallback, prompt, tools, model, opts}, _from, state) do
    providers =
      state.providers
      |> Map.values()
      |> Enum.filter(& &1.enabled)
      |> then(fn filtered ->
        if model do
          Enum.filter(filtered, &provider_supports_model?(&1, model))
        else
          filtered
        end
      end)
      |> Enum.sort_by(& &1.priority, :desc)

    config = Keyword.get(opts, :config, %{})
    cost_limit = Keyword.get(opts, :cost_limit_usd)

    result =
      providers
      |> Enum.reduce_while({:error, "all_providers_exhausted"}, fn provider, _acc ->
        # Check cost limit if specified
        if cost_limit do
          input_tokens = estimate_tokens(prompt)
          est_cost = provider.module.estimate_cost(model || "default", input_tokens, 500)
          if est_cost > cost_limit do
            {:cont, {:error, "cost_limit_exceeded"}}
          else
            attempt_call(provider, prompt, tools, config, model)
          end
        else
          attempt_call(provider, prompt, tools, config, model)
        end
      end)

    {:reply, result, state}
  end

  def handle_call({:health, provider_id}, _from, state) do
    {:reply, Map.get(state.health, provider_id), state}
  end

  def handle_call({:set_enabled, provider_id, enabled}, _from, state) do
    case Map.get(state.providers, provider_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      provider ->
        updated = %{provider | enabled: enabled}
        new_providers = Map.put(state.providers, provider_id, updated)
        {:reply, :ok, %{state | providers: new_providers}}
    end
  end

  @impl true
  def handle_cast({:record_health, provider_id, status, metadata}, state) do
    current = Map.get(state.health, provider_id, %{
      total_calls: 0,
      successes: 0,
      failures: 0,
      last_error: nil,
      last_error_at: nil,
      last_success_at: nil
    })

    updated =
      case status do
        :ok ->
          %{current |
            total_calls: current.total_calls + 1,
            successes: current.successes + 1,
            last_success_at: DateTime.utc_now()
          }

        :error ->
          %{current |
            total_calls: current.total_calls + 1,
            failures: current.failures + 1,
            last_error: metadata,
            last_error_at: DateTime.utc_now()
          }
      end

    new_health = Map.put(state.health, provider_id, updated)
    {:noreply, %{state | health: new_health}}
  end

  # Private helpers

  defp register_builtin_providers(_state) do
    # Will be registered via app config on startup
    {:ok, %{}}
  end

  defp provider_supports_model?(provider, model) do
    # If provider has no model list, assume it supports all
    provider.models == [] or model in provider.models
  end

  defp attempt_call(provider, prompt, tools, config, model) do
    merged_config = Map.merge(provider.config, config)
    merged_config = if model and model != "", do: Map.put(merged_config, :model, model), else: merged_config

    case provider.module.call(prompt, tools, merged_config) do
      {:ok, response} ->
        record_health(provider.id, :ok)
        {:halt, {:ok, response}}

      {:error, reason} ->
        record_health(provider.id, :error, reason)
        {:cont, {:error, reason}}
    end
  end

  defp estimate_tokens(text) when is_binary(text) do
    # Rough estimate: ~4 chars per token
    div(String.length(text), 4) + 1
  end

  defp estimate_tokens(_), do: 100
end
