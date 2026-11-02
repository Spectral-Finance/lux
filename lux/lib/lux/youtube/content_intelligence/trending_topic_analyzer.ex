defmodule Lux.YouTube.ContentIntelligence.TrendingTopicAnalyzer do
  @moduledoc """
  Analyzes search volume momentum, competition saturation, and evergreen vs viral
  potential for trending topics within creator niches.
  """

  @type trend_evaluation :: %{
          topic: String.t(),
          niche: String.t(),
          search_momentum_percentage: float(),
          competition_saturation: float(),
          opportunity_score: float(),
          lifespan_classification: :viral_spike | :medium_wave | :evergreen,
          recommendation: :produce_immediately | :schedule_in_queue | :monitor_only
        }

  @niche_trending_database %{
    "ai" => [
      {"Autonomous Multi-Agent Frameworks", 185.0, 0.42, :medium_wave},
      {"Local LLM Inference with Ollama", 120.0, 0.55, :evergreen},
      {"Model Context Protocol (MCP) Servers", 260.0, 0.28, :medium_wave},
      {"AI Code Assistants Benchmark", 95.0, 0.68, :evergreen}
    ],
    "web3" => [
      {"Account Abstraction ERC-4337", 110.0, 0.40, :evergreen},
      {"Zero Knowledge Proof Verification", 140.0, 0.35, :evergreen},
      {"AI Agent Token Economies", 220.0, 0.50, :medium_wave},
      {"Solana DePIN Architecture", 175.0, 0.45, :medium_wave}
    ],
    "tech" => [
      {"Elixir OTP at Enterprise Scale", 80.0, 0.25, :evergreen},
      {"Rust WebAssembly Microservices", 130.0, 0.38, :evergreen},
      {"Event-Driven Distributed Systems", 95.0, 0.45, :evergreen}
    ]
  }

  @doc """
  Fetches and scores trending topics for a target niche.
  """
  @spec analyze_niche_trends(String.t()) :: list(trend_evaluation())
  def analyze_niche_trends(niche) when is_binary(niche) do
    key = String.downcase(niche)
    dataset = Map.get(@niche_trending_database, key, Map.get(@niche_trending_database, "tech"))

    Enum.map(dataset, fn {topic, momentum, saturation, lifespan} ->
      opportunity = calculate_opportunity_score(momentum, saturation)

      rec =
        cond do
          opportunity >= 80.0 -> :produce_immediately
          opportunity >= 60.0 -> :schedule_in_queue
          true -> :monitor_only
        end

      %{
        topic: topic,
        niche: key,
        search_momentum_percentage: momentum,
        competition_saturation: saturation,
        opportunity_score: opportunity,
        lifespan_classification: lifespan,
        recommendation: rec
      }
    end)
    |> Enum.sort_by(& &1.opportunity_score, :desc)
  end

  @doc """
  Evaluates an arbitrary custom topic's trend viability.
  """
  @spec evaluate_custom_topic(String.t(), String.t(), map()) :: trend_evaluation()
  def evaluate_custom_topic(topic, niche, metrics \\ %{}) do
    momentum = Map.get(metrics, :momentum, Map.get(metrics, "momentum", 110.0))
    saturation = Map.get(metrics, :saturation, Map.get(metrics, "saturation", 0.45))
    lifespan = Map.get(metrics, :lifespan, Map.get(metrics, "lifespan", :medium_wave))

    opportunity = calculate_opportunity_score(momentum, saturation)

    rec =
      cond do
        opportunity >= 80.0 -> :produce_immediately
        opportunity >= 60.0 -> :schedule_in_queue
        true -> :monitor_only
      end

    %{
      topic: topic,
      niche: niche,
      search_momentum_percentage: momentum,
      competition_saturation: saturation,
      opportunity_score: opportunity,
      lifespan_classification: lifespan,
      recommendation: rec
    }
  end

  defp calculate_opportunity_score(momentum, saturation) do
    # Opportunity = high momentum balanced by low competition saturation
    score = (momentum * 0.4) + ((1.0 - saturation) * 60.0)
    Float.round(min(max(score, 0.0), 100.0), 1)
  end
end
