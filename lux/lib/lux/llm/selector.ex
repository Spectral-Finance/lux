defmodule Lux.LLM.Selector do
  @moduledoc """
  Automatic model selection for the Lux LLM provider layer.

  Given a set of `Lux.LLM.Registry` entries and the requirements of a single
  call, `rank/2` returns the candidates ordered from best to worst, applying
  hard filters first and a weighted score second.

  ## Requirements

  A requirements map understands the following keys (all optional):

    * `:prompt_tokens` — estimated prompt size; entries whose `:max_context`
      is smaller are filtered out
    * `:tools` — when a non-empty list, providers must declare the `:tools`
      model capability
    * `:max_cost_usd` — estimated cost ceiling for this call (USD)
    * `:max_latency_ms` — soft preference for faster providers
    * `:quality` — `:cheap` (cost-first), `:balanced` (default) or `:best`
      (capability-first); shifts the scoring weights
    * `:providers` — explicit allow-list of provider modules
  """

  @type requirements :: %{
          optional(:prompt_tokens) => pos_integer(),
          optional(:tools) => [term()],
          optional(:max_cost_usd) => number(),
          optional(:max_latency_ms) => pos_integer(),
          optional(:quality) => :cheap | :balanced | :best,
          optional(:providers) => [module()]
        }

  @default_weights %{
    cost: 0.35,
    context: 0.2,
    capability: 0.2,
    speed: 0.15,
    weight: 0.1
  }

  @doc """
  Ranks registry entries for a given requirement set.

  Returns `[]` when no candidate satisfies the hard requirements.
  """
  @spec rank([Lux.LLM.Registry.entry()], requirements()) :: [Lux.LLM.Registry.entry()]
  def rank(entries, requirements \\ %{}) do
    requirements = normalize(requirements)

    entries
    |> Enum.filter(&usable?(&1, requirements))
    |> Enum.map(fn entry ->
      models = candidate_models(entry, requirements)
      best = best_model(entry, models, requirements)
      {entry, best, score(entry, best, requirements)}
    end)
    |> Enum.reject(fn {_entry, best, _score} -> is_nil(best) end)
    |> Enum.sort_by(fn {_entry, _best, score} -> -score end)
    |> Enum.map(fn {entry, best, _score} ->
      model = best.id
      %{entry | config: Map.put(entry.config || %{}, :model, model)}
    end)
  end

  @doc """
  Same as `rank/2` but returns a single best entry (or `nil`).
  """
  @spec select([Lux.LLM.Registry.entry()], requirements()) ::
          Lux.LLM.Registry.entry() | nil
  def select(entries, requirements \\ %{}) do
    List.first(rank(entries, requirements))
  end

  # --- internals ------------------------------------------------------------

  defp normalize(req) when is_list(req), do: Map.new(req)
  defp normalize(req) when is_map(req), do: Map.merge(defaults(), req)

  defp defaults do
    %{
      prompt_tokens: 1_000,
      tools: [],
      max_cost_usd: nil,
      max_latency_ms: nil,
      quality: :balanced,
      providers: nil
    }
  end

  defp usable?(entry, req) do
    entry.status == :up and
      (is_nil(req.providers) or entry.module in req.providers) and
      Enum.any?(entry.meta.models, fn m -> m.max_context >= req.prompt_tokens end)
  end

  defp candidate_models(entry, req) do
    entry.meta.models
    |> Enum.filter(fn m -> m.max_context >= req.prompt_tokens end)
    |> maybe_filter_tools(req.tools)
    |> maybe_filter_cost(req)
  end

  defp maybe_filter_tools(models, []), do: models

  defp maybe_filter_tools(models, _tools) do
    case Enum.filter(models, &(:tools in Map.get(&1, :capabilities, []))) do
      [] -> models
      filtered -> filtered
    end
  end

  defp maybe_filter_cost(models, %{max_cost_usd: nil}), do: models

  defp maybe_filter_cost(models, req) do
    max_cost = req.max_cost_usd
    out_tokens = max(div(req.prompt_tokens, 4), 256)

    affordable =
      Enum.filter(models, fn m ->
        cost(m, req.prompt_tokens, out_tokens) <= max_cost
      end)

    case affordable do
      [] -> models
      list -> list
    end
  end

  defp best_model(_entry, [], _req), do: nil

  defp best_model(entry, models, req) do
    models
    |> Enum.map(fn m -> {m, score(entry, m, req)} end)
    |> Enum.max_by(fn {_m, s} -> s end)
    |> elem(0)
  end

  defp score(entry, model, req) do
    w = weights(req.quality)

    cost_score =
      cond do
        is_nil(model.input_cost_per_mtok) -> 1.0
        true -> 1.0 - min(cost_per_mtok(model) / 20.0, 1.0)
      end

    context_score = min(model.max_context / 400_000, 1.0)

    capability_score =
      case req.tools do
        [] -> length(Map.get(model, :capabilities, [])) / 3
        _ -> if(:tools in Map.get(model, :capabilities, []), do: 1.0, else: 0.2)
      end

    speed_score =
      cond do
        is_nil(req.max_latency_ms) -> 1.0
        is_nil(model.max_context) -> 1.0
        true -> min(req.max_latency_ms / 5_000, 1.0)
      end

    weight_score = min(entry.weight / 2.0, 1.0)

    w.cost * cost_score +
      w.context * context_score +
      w.capability * capability_score +
      w.speed * speed_score +
      w.weight * weight_score
  end

  defp weights(:cheap), do: %{@default_weights | cost: 0.6, capability: 0.1, context: 0.1, speed: 0.1, weight: 0.1}
  defp weights(:best), do: %{@default_weights | cost: 0.1, capability: 0.45, context: 0.3, speed: 0.05, weight: 0.1}
  defp weights(_), do: @default_weights

  defp cost_per_mtok(model), do: model.input_cost_per_mtok + model.output_cost_per_mtok

  defp cost(model, prompt_tokens, out_tokens) do
    model.input_cost_per_mtok * prompt_tokens / 1_000_000 +
      model.output_cost_per_mtok * out_tokens / 1_000_000
  end
end
