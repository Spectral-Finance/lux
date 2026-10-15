defmodule Lux.LLM.ModelSelector do
  @moduledoc """
  Automatic LLM provider and model selection engine.

  Evaluates task complexity, required capabilities (such as tool calling, JSON
  schema output, reasoning, and context length), provider health, and optimization
  strategy (`:cost_optimized`, `:quality_optimized`, `:latency_optimized`, or
  `:balanced`) to rank and select the optimal `{provider, model}` candidate.
  """

  alias Lux.LLM.Provider.ModelInfo
  alias Lux.LLM.Provider.Spec
  alias Lux.LLM.ProviderRegistry
  alias Lux.LLM.Telemetry

  @type strategy ::
          :cost_optimized
          | :cheapest
          | :quality_optimized
          | :smartest
          | :latency_optimized
          | :fastest
          | :balanced

  @type selection :: %{
          provider: atom(),
          module: module(),
          model: String.t(),
          model_info: ModelInfo.t(),
          spec: Spec.t(),
          score: float()
        }

  @reasoning_keywords [
    "analyze",
    "reason",
    "step by step",
    "prove",
    "complex",
    "architecture",
    "optimize",
    "compare",
    "evaluate",
    "synthesiz"
  ]

  @doc """
  Estimates prompt complexity (`:simple`, `:moderate`, or `:complex`) based on
  prompt length, reasoning indicators, and number of attached tools.
  """
  @spec estimate_complexity(term(), list()) :: :simple | :moderate | :complex
  def estimate_complexity(prompt, tools \\ []) do
    text = extract_prompt_text(prompt)
    tokens = Telemetry.estimate_tokens(text)
    tool_count = length(tools || [])
    has_reasoning = contains_reasoning_keyword?(text)

    cond do
      tokens > 1_500 or tool_count >= 4 or (has_reasoning and tokens > 200) ->
        :complex

      tokens > 250 or tool_count >= 1 or has_reasoning ->
        :moderate

      true ->
        :simple
    end
  end

  @doc """
  Selects the single best `{provider, model}` candidate for the given prompt,
  tools, and routing options.
  """
  @spec select(term(), list(), map()) :: {:ok, selection()} | {:error, :no_matching_model}
  def select(prompt, tools \\ [], opts \\ %{}) when is_map(opts) do
    case rank_candidates(prompt, tools, opts) do
      [best | _] -> {:ok, best}
      [] -> {:error, :no_matching_model}
    end
  end

  @doc """
  Ranks all eligible `{provider, model}` candidates in descending order of score.
  """
  @spec rank_candidates(term(), list(), map()) :: [selection()]
  def rank_candidates(prompt, tools \\ [], opts \\ %{}) when is_map(opts) do
    strategy = Map.get(opts, :strategy, :balanced)
    complexity = Map.get(opts, :complexity) || estimate_complexity(prompt, tools)
    required_caps = infer_required_capabilities(tools, opts, complexity)
    min_context = Map.get(opts, :min_context_window, Telemetry.estimate_tokens(prompt) + 512)
    max_cost = Map.get(opts, :max_cost_per_1k)
    allowed_providers = allowed_provider_filter(opts)

    [only_enabled: true, only_healthy: true]
    |> ProviderRegistry.list_providers()
    |> Enum.filter(&provider_allowed?(&1, allowed_providers))
    |> Enum.flat_map(&expand_provider_candidates(&1, opts))
    |> Enum.filter(fn %{model_info: info} ->
      capabilities_match?(info, required_caps) and
        info.context_window >= min_context and
        within_cost_budget?(info, max_cost)
    end)
    |> Enum.map(fn candidate ->
      score = score_candidate(candidate, strategy, complexity)
      Map.put(candidate, :score, score)
    end)
    |> Enum.sort_by(& &1.score, :desc)
  end

  defp allowed_provider_filter(opts) do
    cond do
      is_list(opts[:providers]) and opts[:providers] != [] ->
        opts[:providers]

      is_atom(opts[:provider]) and not is_nil(opts[:provider]) ->
        fallbacks = List.wrap(opts[:fallback_providers])
        Enum.uniq([opts[:provider] | fallbacks])

      true ->
        :all
    end
  end

  defp provider_allowed?(_spec, :all), do: true
  defp provider_allowed?(%Spec{id: id}, allowed) when is_list(allowed), do: id in allowed

  defp expand_provider_candidates(%Spec{} = spec, opts) do
    explicit_model = Map.get(opts, :model)
    explicit_provider = Map.get(opts, :provider)
    matches_provider = is_nil(explicit_provider) or explicit_provider == spec.id

    models =
      if is_binary(explicit_model) and matches_provider do
        case Enum.find(spec.models, &(&1.name == explicit_model)) do
          nil ->
            [
              %ModelInfo{
                name: explicit_model,
                provider: spec.id,
                tier: :balanced,
                capabilities: [:tools, :json_mode, :reasoning]
              }
            ]

          found ->
            [found]
        end
      else
        spec.models
      end

    Enum.map(models, fn info ->
      %{
        provider: spec.id,
        module: spec.module,
        model: info.name,
        model_info: info,
        spec: spec,
        score: 0.0
      }
    end)
  end

  defp infer_required_capabilities(tools, opts, complexity) do
    explicit = Map.get(opts, :required_capabilities, [])
    needs_tools = if is_list(tools) and tools != [], do: [:tools], else: []

    needs_reasoning =
      if complexity == :complex and opts[:require_reasoning] do
        [:reasoning]
      else
        []
      end

    Enum.uniq(explicit ++ needs_tools ++ needs_reasoning)
  end

  defp capabilities_match?(%ModelInfo{capabilities: caps}, required) do
    Enum.all?(required, &(&1 in caps))
  end

  defp within_cost_budget?(_info, nil), do: true

  defp within_cost_budget?(%ModelInfo{} = info, max_cost) when is_number(max_cost) do
    avg_cost = (info.input_cost_per_1k + info.output_cost_per_1k) / 2.0
    avg_cost <= max_cost
  end

  defp score_candidate(
         %{provider: provider_id, model_info: info, spec: spec},
         strategy,
         complexity
       ) do
    cost_score = compute_cost_score(info)
    quality_score = info.quality_score
    latency_score = compute_latency_score(provider_id, info)
    priority_bonus = spec.priority / 10_000.0
    tier_alignment = complexity_tier_bonus(complexity, info.tier)

    base =
      case strategy do
        s when s in [:cost_optimized, :cheapest] ->
          cost_score * 0.75 + quality_score * 0.15 + latency_score * 0.10

        s when s in [:quality_optimized, :smartest] ->
          quality_score * 0.80 + latency_score * 0.10 + cost_score * 0.10

        s when s in [:latency_optimized, :fastest] ->
          latency_score * 0.75 + quality_score * 0.15 + cost_score * 0.10

        _balanced ->
          quality_score * 0.35 + cost_score * 0.30 + latency_score * 0.20 + tier_alignment * 0.15
      end

    Float.round(base + priority_bonus, 6)
  end

  defp compute_cost_score(%ModelInfo{input_cost_per_1k: input, output_cost_per_1k: output}) do
    blended = (input + output) / 2.0
    1.0 / (1.0 + blended * 200.0)
  end

  defp compute_latency_score(provider_id, %ModelInfo{name: name, avg_latency_ms: static_ms}) do
    effective_ms = Telemetry.observed_latency_ms(provider_id, name) || static_ms
    1.0 / (1.0 + effective_ms / 500.0)
  end

  defp complexity_tier_bonus(:simple, :cheapest), do: 1.0
  defp complexity_tier_bonus(:simple, :fast), do: 0.9
  defp complexity_tier_bonus(:simple, :balanced), do: 0.5
  defp complexity_tier_bonus(:simple, :smartest), do: 0.2
  defp complexity_tier_bonus(:moderate, :balanced), do: 1.0
  defp complexity_tier_bonus(:moderate, :cheapest), do: 0.7
  defp complexity_tier_bonus(:moderate, :smartest), do: 0.7
  defp complexity_tier_bonus(:complex, :smartest), do: 1.0
  defp complexity_tier_bonus(:complex, :balanced), do: 0.75
  defp complexity_tier_bonus(:complex, _), do: 0.2

  defp extract_prompt_text(prompt) when is_binary(prompt), do: prompt

  defp extract_prompt_text(messages) when is_list(messages) do
    Enum.map_join(messages, " ", fn
      %{content: content} when is_binary(content) -> content
      %{"content" => content} when is_binary(content) -> content
      msg when is_binary(msg) -> msg
      other -> inspect(other)
    end)
  end

  defp extract_prompt_text(other), do: inspect(other)

  defp contains_reasoning_keyword?(text) do
    downcased = String.downcase(text)
    Enum.any?(@reasoning_keywords, &String.contains?(downcased, &1))
  end
end
