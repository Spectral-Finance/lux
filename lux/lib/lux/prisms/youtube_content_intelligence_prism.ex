defmodule Lux.Prisms.YouTubeContentIntelligencePrism do
  @moduledoc """
  A Prism for autonomous agents to perform YouTube content analytics,
  metadata generation, CTR optimization, and topic forecasting.

  ## Examples

      iex> Lux.Prisms.YouTubeContentIntelligencePrism.run(%{
      ...>   action: "optimize_title",
      ...>   payload: %{title: "Building Production Multi-Agent Systems with Lux"}
      ...> })
      {:ok, %{action: "optimize_title", result: %{ctr_potential_score: 75.0, ...}}}
  """

  use Lux.Prism,
    name: "YouTube Content Intelligence Prism",
    description: "Analyzes video performance, optimizes titles/thumbnails, predicts peak posting windows, and generates SEO metadata packages",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: [
            "evaluate_performance",
            "predict_posting_time",
            "optimize_title",
            "generate_title_variants",
            "audit_thumbnail",
            "generate_metadata",
            "recommend_topics",
            "analyze_trends",
            "audit_video"
          ],
          description: "Content intelligence action to execute"
        },
        payload: %{
          type: :object,
          description: "Payload data corresponding to chosen action"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        result: %{type: :object}
      },
      required: ["action", "result"]
    }

  alias Lux.YouTube.ContentIntelligence

  def handler(input, _context) do
    action = Map.get(input, :action) || Map.get(input, "action", "audit_video")
    payload = Map.get(input, :payload) || Map.get(input, "payload", %{})

    case execute_action(action, payload) do
      {:ok, result} ->
        {:ok, %{action: action, result: result}}

      {:error, reason} ->
        {:error, "YouTubeContentIntelligencePrism error on action '#{action}': #{inspect(reason)}"}
    end
  end

  defp execute_action("evaluate_performance", payload) do
    stats = Map.get(payload, :stats, Map.get(payload, "stats", payload))
    baseline = Map.get(payload, :baseline, Map.get(payload, "baseline", %{}))
    {:ok, ContentIntelligence.evaluate_performance(stats, baseline)}
  end

  defp execute_action("predict_posting_time", payload) do
    {:ok, ContentIntelligence.predict_posting_time(payload)}
  end

  defp execute_action("optimize_title", payload) do
    title = Map.get(payload, :title, Map.get(payload, "title", ""))
    {:ok, ContentIntelligence.analyze_title(title)}
  end

  defp execute_action("generate_title_variants", payload) do
    topic = Map.get(payload, :topic, Map.get(payload, "topic", "Engineering Deep Dive"))
    {:ok, %{variants: ContentIntelligence.generate_title_variants(topic)}}
  end

  defp execute_action("audit_thumbnail", payload) do
    {:ok, ContentIntelligence.audit_thumbnail(payload)}
  end

  defp execute_action("generate_metadata", payload) do
    {:ok, ContentIntelligence.generate_metadata(payload)}
  end

  defp execute_action("recommend_topics", payload) do
    past_videos = Map.get(payload, :past_videos, Map.get(payload, "past_videos", []))
    niche = Map.get(payload, :niche, Map.get(payload, "niche", "tech"))
    {:ok, %{recommendations: ContentIntelligence.recommend_topics(past_videos, niche)}}
  end

  defp execute_action("analyze_trends", payload) do
    niche = Map.get(payload, :niche, Map.get(payload, "niche", "tech"))
    {:ok, %{trends: ContentIntelligence.analyze_trends(niche)}}
  end

  defp execute_action("audit_video", payload) do
    baseline = Map.get(payload, :baseline, Map.get(payload, "baseline", %{}))
    {:ok, ContentIntelligence.audit_video(payload, baseline)}
  end

  defp execute_action(unknown, _payload) do
    {:error, "Unknown action: #{unknown}"}
  end
end
