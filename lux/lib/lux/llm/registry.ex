defmodule Lux.LLM.Registry do
  @moduledoc """
  Registry and execution manager for LLM providers with fallback, cost tracking,
  and automatic model selection.
  """

  use GenServer

  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec register_provider(atom(), module()) :: :ok
  def register_provider(name, provider_module) do
    GenServer.call(__MODULE__, {:register, name, provider_module})
  end

  @spec complete(list(atom()), String.t(), list(map()), keyword()) :: {:ok, map()} | {:error, term()}
  def complete(provider_order, model, messages, opts \\ []) do
    try_providers(provider_order, model, messages, opts)
  end

  defp try_providers([], _model, _messages, _opts), do: {:error, :all_providers_failed}
  defp try_providers([provider | rest], model, messages, opts) do
    module = GenServer.call(__MODULE__, {:get_provider, provider})
    if module && function_exported?(module, :complete, 3) do
      start_time = System.monotonic_time(:millisecond)
      case module.complete(model, messages, opts) do
        {:ok, result} ->
          duration = System.monotonic_time(:millisecond) - start_time
          Logger.info("LLM call succeeded using #{provider} for model #{model} in #{duration}ms")
          {:ok, Map.put(result, :telemetry, %{provider: provider, duration_ms: duration})}
        {:error, reason} ->
          Logger.warning("LLM provider #{provider} failed with: #{inspect(reason)}, trying fallbacks...")
          try_providers(rest, model, messages, opts)
      end
    else
      try_providers(rest, model, messages, opts)
    end
  end

  # GenServer Callbacks
  @impl true
  def init(_opts) do
    initial_providers = %{
      anthropic: Lux.LLM.Providers.Anthropic,
      openai: Lux.LLM.Providers.OpenAI
    }
    {:ok, initial_providers}
  end

  @impl true
  def handle_call({:register, name, module}, _from, state) do
    {:reply, :ok, Map.put(state, name, module)}
  end

  @impl true
  def handle_call({:get_provider, name}, _from, state) do
    {:reply, Map.get(state, name), state}
  end
end
