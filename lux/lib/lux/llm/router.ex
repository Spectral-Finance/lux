defmodule Lux.LLM.Router do
  @moduledoc """
  Automatic model selection and intelligent routing engine for LLM requests.

  Selects the optimal provider and model based on user intent, constraints,
  capabilities (e.g. tools, vision), and optimization strategies:
  - `:cost_optimized` - Chooses free or economy providers (e.g. Ollama, Together AI).
  - `:performance` - Prioritizes low latency and high throughput.
  - `:reasoning_quality` - Selects top-tier frontier models (Claude 3.5 Sonnet, GPT-4o).
  - `:research` - Routes to search-augmented LLMs (Perplexity).
  - `:offline_privacy` - Routes strictly to local models (Ollama).
  """

  alias Lux.LLM.Registry

  @doc """
  Selects the optimal provider and model given execution criteria and constraints.
  """
  @spec select_provider(map() | keyword()) :: {:ok, map()} | {:error, term()}
  def select_provider(opts) do
    strategy = get_opt(opts, :strategy, :balanced)
    require_tools = get_opt(opts, :require_tools, false)
    preferred_provider = get_opt(opts, :preferred_provider, nil)

    # 1. Filter by preferred provider if specified and enabled
    if preferred_provider do
      case Registry.get_provider(preferred_provider) do
        {:ok, %{enabled: true} = provider} ->
          {:ok, enrich_selection(provider, opts)}

        _ ->
          do_strategy_selection(strategy, require_tools, opts)
      end
    else
      do_strategy_selection(strategy, require_tools, opts)
    end
  end

  defp do_strategy_selection(strategy, require_tools, opts) do
    candidates =
      Registry.list_enabled_providers()
      |> filter_by_tools(require_tools)

    case strategy do
      :offline_privacy ->
        case Enum.find(candidates, &(:local in &1.capabilities)) do
          nil -> {:error, "No local/offline provider available"}
          provider -> {:ok, enrich_selection(provider, opts)}
        end

      :research ->
        case Enum.find(candidates, &(:research in &1.capabilities or :web_search in &1.capabilities)) do
          nil -> fallback_to_top_candidate(candidates, opts)
          provider -> {:ok, enrich_selection(provider, opts)}
        end

      :cost_optimized ->
        # Prefer free -> economy -> standard -> premium
        sorted =
          Enum.sort_by(candidates, fn p ->
            case p.cost_tier do
              :free -> 1
              :economy -> 2
              :variable -> 3
              :standard -> 4
              :premium -> 5
              _ -> 6
            end
          end)

        case sorted do
          [best | _] -> {:ok, enrich_selection(best, opts)}
          [] -> {:error, "No suitable provider found for cost optimization"}
        end

      :reasoning_quality ->
        # Prefer premium / frontier models
        sorted =
          Enum.sort_by(candidates, fn p ->
            case p.cost_tier do
              :premium -> 1
              :standard -> 2
              _ -> 3
            end
          end)

        case sorted do
          [best | _] -> {:ok, enrich_selection(best, opts)}
          [] -> {:error, "No suitable provider found for high reasoning quality"}
        end

      _balanced ->
        fallback_to_top_candidate(candidates, opts)
    end
  end

  defp filter_by_tools(candidates, true) do
    Enum.filter(candidates, &(:tool_calling in &1.capabilities))
  end

  defp filter_by_tools(candidates, false), do: candidates

  defp fallback_to_top_candidate([best | _], opts) do
    {:ok, enrich_selection(best, opts)}
  end

  defp fallback_to_top_candidate([], _opts) do
    {:error, "No enabled LLM provider satisfies constraints"}
  end

  defp enrich_selection(provider, opts) do
    model = get_opt(opts, :model, provider.default_model)
    %{
      provider_id: provider.id,
      provider_name: provider.name,
      module: provider.module,
      model: model,
      capabilities: provider.capabilities,
      cost_tier: provider.cost_tier
    }
  end

  defp get_opt(opts, key, default) when is_map(opts) do
    Map.get(opts, key) || Map.get(opts, to_string(key), default)
  end

  defp get_opt(opts, key, default) when is_list(opts) do
    Keyword.get(opts, key, default)
  end
end
