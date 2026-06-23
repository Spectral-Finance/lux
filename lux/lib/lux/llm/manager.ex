defmodule Lux.LLM.Manager do
  @moduledoc """
  A universal provider interface to manage multiple LLM providers efficiently.
  Supports automatic model selection, fallback handling, caching, and performance monitoring.
  """

  @behaviour Lux.LLM

  alias Lux.LLM.ResponseSignal
  alias Lux.Signal

  require Logger

  # Default fallback list of providers
  @default_providers [
    Lux.LLM.OpenAI,
    Lux.LLM.Anthropic,
    Lux.LLM.TogetherAI,
    Lux.LLM.OpenRouter,
    Lux.LLM.Perplexity,
    Lux.LLM.Ollama
  ]

  @impl true
  def call(prompt, tools, config) do
    # Merge options
    config = Map.new(config)
    
    # Check cache first (if caching is enabled)
    use_cache = Map.get(config, :cache, true)
    cache_key = {prompt, tools, Map.delete(config, :cache)}
    
    case check_cache(use_cache, cache_key) do
      :miss ->
        # Resolve which provider(s) to use
        providers = resolve_providers(config)

        # Attempt to call providers in order
        case execute_with_fallback(prompt, tools, providers) do
          {:ok, response, provider} ->
            # Save to cache and log metrics
            save_cache(use_cache, cache_key, response)
            log_metric(provider, :success)
            {:ok, response}

          {:error, reason} ->
            # Log failure
            {:error, reason}
        end

      cached_response ->
        {:ok, cached_response}
    end
  end

  defp check_cache(true, key) do
    case GenServer.whereis(Lux.LLM.Manager.Server) do
      nil -> :miss
      pid -> GenServer.call(pid, {:get_cache, key})
    end
  end
  defp check_cache(_, _), do: :miss

  defp save_cache(true, key, val) do
    case GenServer.whereis(Lux.LLM.Manager.Server) do
      nil -> :ok
      pid -> GenServer.cast(pid, {:put_cache, key, val})
    end
  end
  defp save_cache(_, _, _), do: :ok

  defp log_metric(provider, status) do
    case GenServer.whereis(Lux.LLM.Manager.Server) do
      nil -> :ok
      pid -> GenServer.cast(pid, {:log_metric, provider, status})
    end
  end

  # Resolves the list of providers to try based on config or model prefix
  def resolve_providers(%{providers: custom_providers}) when is_list(custom_providers) do
    custom_providers
  end
  def resolve_providers(%{model: model} = config) when is_binary(model) do
    # Automatic model selection based on prefix
    provider =
      cond do
        String.starts_with?(model, "gpt") -> Lux.LLM.OpenAI
        String.starts_with?(model, "claude") -> Lux.LLM.Anthropic
        String.starts_with?(model, "sonar") -> Lux.LLM.Perplexity
        String.starts_with?(model, "llama") -> Lux.LLM.Ollama
        true -> Lux.LLM.OpenRouter
      end
    
    # Put the best provider first, then fall back to others
    [provider | List.delete(@default_providers, provider)]
  end
  def resolve_providers(_) do
    @default_providers
  end

  defp execute_with_fallback(prompt, tools, [provider | rest]) do
    start_time = System.monotonic_time(:millisecond)
    
    # Ensure provider is loaded and has correct behavior
    case call_provider(provider, prompt, tools) do
      {:ok, response} ->
        elapsed = System.monotonic_time(:millisecond) - start_time
        Logger.info("Lux.LLM.Manager: Call to #{inspect(provider)} succeeded in #{elapsed}ms")
        {:ok, response, provider}

      {:error, reason} ->
        elapsed = System.monotonic_time(:millisecond) - start_time
        Logger.warning("Lux.LLM.Manager: Call to #{inspect(provider)} failed after #{elapsed}ms: #{inspect(reason)}")
        log_metric(provider, :failure)
        
        # Check if we have fallbacks left
        if rest != [] do
          Logger.info("Lux.LLM.Manager: Falling back to #{inspect(hd(rest))}")
          execute_with_fallback(prompt, tools, rest)
        else
          {:error, "All LLM providers failed. Last error from #{inspect(provider)}: #{inspect(reason)}"}
        end
    end
  end
  defp execute_with_fallback(_prompt, _tools, []) do
    {:error, "No providers configured"}
  end

  defp call_provider(provider, prompt, tools) do
    # Try calling the provider module's call/3 function
    try do
      provider.call(prompt, tools, %{})
    rescue
      e -> {:error, "Exception in #{inspect(provider)}: #{Exception.message(e)}"}
    catch
      kind, payload -> {:error, "Catch in #{inspect(provider)}: #{inspect({kind, payload})}"}
    end
  end
end

defmodule Lux.LLM.Manager.Server do
  @moduledoc """
  GenServer to handle metrics collection and caching for Lux.LLM.Manager.
  """
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: Lux.LLM.Manager.Server)
  end

  @impl true
  def init(:ok) do
    {:ok, %{cache: %{}, metrics: %{}}}
  end

  @impl true
  def handle_call(:clear, _from, _state) do
    {:reply, :ok, %{cache: %{}, metrics: %{}}}
  end

  @impl true
  def handle_call({:get_cache, key}, _from, state) do
    res = Map.get(state.cache, key, :miss)
    {:reply, res, state}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    {:reply, state.metrics, state}
  end

  @impl true
  def handle_cast({:put_cache, key, val}, state) do
    new_cache = Map.put(state.cache, key, val)
    {:noreply, %{state | cache: new_cache}}
  end

  @impl true
  def handle_cast({:log_metric, provider, status}, state) do
    provider_metrics = Map.get(state.metrics, provider, %{success: 0, failure: 0})
    updated_metrics = Map.update!(provider_metrics, status, &(&1 + 1))
    new_metrics = Map.put(state.metrics, provider, updated_metrics)
    {:noreply, %{state | metrics: new_metrics}}
  end
end
