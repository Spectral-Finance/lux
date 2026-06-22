defmodule Lux.LLM.ProviderRegistry do
  @moduledoc """
  Universal LLM provider registry and management system.

  Manages multiple LLM providers with automatic model selection,
  smart fallback handling, cost tracking, and performance monitoring.

  ## Usage

      # Register a provider
      ProviderRegistry.register(:openrouter, Lux.LLM.OpenRouter)

      # Call a provider with automatic fallback
      {:ok, response} = ProviderRegistry.call(prompt, tools, model: "anthropic/claude-3")

      # Get provider stats
      stats = ProviderRegistry.stats()
  """

  use GenServer

  alias Lux.LLM.Response

  @type provider_name :: atom()
  @type provider_module :: module()
  @type model_selector :: String.t() | {provider_name(), String.t()}

  @table_name :llm_provider_registry

  # ===================================================================
  # GenServer API
  # ===================================================================

  @doc """
  Starts the provider registry server.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  Registers a new LLM provider.

  ## Examples

      iex> ProviderRegistry.register(:openrouter, Lux.LLM.OpenRouter)
      :ok

      iex> ProviderRegistry.register(:anthropic, Lux.LLM.Anthropic, priority: 1)
      :ok
  """
  @spec register(provider_name(), provider_module(), keyword()) :: :ok | {:error, String.t()}
  def register(name, module, opts \ []) do
    GenServer.call(__MODULE__, {:register, name, module, opts})
  end

  @doc """
  Calls a provider with automatic fallback to registered providers.

  ## Examples

      iex> ProviderRegistry.call("Summarize this text", [], model: "openrouter/claude-3")
      {:ok, %Lux.LLM.Response{content: "..."}}

      iex> ProviderRegistry.call("Hello", [], fallback: [:anthropic, :openai])
      {:ok, %Lux.LLM.Response{content: "..."}}
  """
  @spec call(String.t(), list(), keyword()) :: {:ok, Response.t()} | {:error, String.t()}
  def call(prompt, tools, opts \ []) do
    GenServer.call(__MODULE__, {:call, prompt, tools, opts})
  end

  @doc """
  Gets the module for a registered provider.
  """
  @spec get_module(provider_name()) :: provider_module() | nil
  def get_module(name) do
    GenServer.call(__MODULE__, {:get_module, name})
  end

  @doc """
  Lists all registered providers.
  """
  @spec list_providers() :: [{provider_name(), provider_module(), keyword()}]
  def list_providers do
    GenServer.call(__MODULE__, {:list_providers})
  end

  @doc """
  Gets statistics for all providers.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, {:stats})
  end

  @doc """
  Resets all provider statistics.
  """
  @spec reset_stats() :: :ok
  def reset_stats do
    GenServer.call(__MODULE__, {:reset_stats})
  end

  # ===================================================================
  # GenServer Callbacks
  # ===================================================================

  @impl true
  def init(_opts) do
    :ets.new(@table_name, [:named_table, :set, :private, :named_table])
    {:ok, %{providers: %{}, stats: %{}, call_count: 0}}
  end

  @impl true
  def handle_call({:register, name, module, opts}, _from, state) do
    priority = Keyword.get(opts, :priority, 0)
    enabled = Keyword.get(opts, :enabled, true)
    cost_per_token = Keyword.get(opts, :cost_per_token, 0)

    :ets.insert(@table_name, {name, %{module: module, priority: priority, enabled: enabled, cost_per_token: cost_per_token}})

    new_providers = Map.put(state.providers, name, %{module: module, priority: priority, enabled: enabled, cost_per_token: cost_per_token})

    {:reply, :ok, %{state | providers: new_providers}}
  end

  @impl true
  def handle_call({:call, prompt, tools, opts}, _from, state) do
    model = Keyword.get(opts, :model, "")
    fallbacks = Keyword.get(opts, :fallback, [])
    start_time = System.monotonic_time(:millisecond)

    # Determine which providers to try
    providers_to_try = determine_providers(model, fallbacks, state.providers)

    # Try each provider in order
    result = try_providers(prompt, tools, providers_to_try, opts)

    elapsed = System.monotonic_time(:millisecond) - start_time

    # Update stats
    new_stats = update_stats(result, elapsed, state.stats)
    new_call_count = state.call_count + 1

    {:reply, result, %{state | stats: new_stats, call_count: new_call_count}}
  end

  @impl true
  def handle_call({:get_module, name}, _from, state) do
    provider = Map.get(state.providers, name)
    module = provider && provider.module
    {:reply, module, state}
  end

  @impl true
  def handle_call({:list_providers}, _from, state) do
    providers =
      state.providers
      |> Map.to_list()
      |> Enum.sort_by(elem(&1, 1).priority, :desc)

    {:reply, providers, state}
  end

  @impl true
  def handle_call({:stats}, _from, state) do
    {:reply, %{state.stats, total_calls: state.call_count}, state}
  end

  @impl true
  def handle_call({:reset_stats}, _from, state) do
    {:reply, :ok, %{state | stats: %{}, call_count: 0}}
  end

  # ===================================================================
  # Private Functions
  # ===================================================================

  defp determine_providers(model, fallbacks, providers) do
    # Parse model to get provider name
    {provider_name, _} = parse_model(model)

    # If provider is registered and enabled, use it
    if provider_name && Map.has_key?(providers, provider_name) do
      [provider_name]
    else
      # Use fallbacks or all enabled providers sorted by priority
      Enum.filter(fallbacks, &Map.has_key?(providers, &1))
      |> then(fn fb ->
        if Enum.empty?(fb) do
          providers
          |> Map.filter(fn _, v -> v.enabled end)
          |> Map.keys()
          |> Enum.sort_by(fn name -> providers[name].priority end, :desc)
        else
          fb
        end
      end)
    end
  end

  defp parse_model(model) do
    case String.split(model, "/", parts: 2) do
      [provider, _] -> {String.to_atom(provider), model}
      [model_name] -> {nil, model_name}
      _ -> {nil, model}
    end
  end

  defp try_providers(prompt, tools, provider_names, opts) do
    Enum.reduce(provider_names, {:error, "No providers available"}, fn name, acc ->
      case acc do
        {:ok, _} = success -> success
        _ ->
          provider = Map.get(acc, :provider) || Map.get(Map.get(acc, :detail), :provider)
          case call_provider(name, prompt, tools, opts) do
            {:ok, response} -> {:ok, response}
            {:error, _} = error -> error
          end
      end
    end)
  end

  defp call_provider(name, prompt, tools, opts) do
    case get_provider_module(name) do
      nil ->
        {:error, "Provider #{name} not registered"}

      module ->
        try do
          module.call(prompt, tools, opts)
        rescue
          e ->
            Logger.error("Provider #{name} call failed: #{inspect(e)}")
            {:error, "Provider #{name} error: #{inspect(e)}"}
        end
    end
  end

  defp get_provider_module(name) do
    case :ets.lookup(@table_name, name) do
      [{^name, %{module: module}}] -> module
      [] -> nil
    end
  end

  defp update_stats({:ok, _response}, elapsed, stats) do
    Map.put(stats, :success_count, Map.get(stats, :success_count, 0) + 1)
    |> Map.put_lazy(:avg_latency, fn s ->
      prev_avg = Map.get(s, :avg_latency, 0)
      count = Map.get(s, :success_count, 1)
      ((prev_avg * (count - 1)) + elapsed) / count
    end)
  end

  defp update_stats({:error, _}, elapsed, stats) do
    Map.put(stats, :failure_count, Map.get(stats, :failure_count, 0) + 1)
  end
end
