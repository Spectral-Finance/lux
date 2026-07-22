defmodule Lux.Agents.YouTubeContentIntelligence do
  @moduledoc """
  An agent that analyzes YouTube content, engagement, and metadata using AI models
  and provides predictive analytics for optimal posting times and performance.

  ## Examples

      iex> {:ok, agent} = Lux.Agents.YouTubeContentIntelligence.start_link([])
      iex> video_context = %{
      ...>   "title" => "My new vlog",
      ...>   "metrics" => %{"views" => 100, "likes" => 10}
      ...> }
      iex> Lux.Agents.YouTubeContentIntelligence.optimize_content(agent, video_context)
      {:ok, %{title: "Optimized Title", ...}}

      iex> metrics = [%{"hour" => 10, "views" => 1000}, %{"hour" => 18, "views" => 5000}]
      iex> Lux.Agents.YouTubeContentIntelligence.predict_performance(metrics)
      %{"optimal_posting_hour" => 18, "predicted_views" => 6325, "confidence_score" => 0.2, "estimated_retention" => 50.0}
  """

  use Lux.Agent,
    name: "YouTube Content Intelligence",
    description: "Analyzes YouTube metrics and generates metadata for content optimization",
    goal: "Provide actionable insights, predictions, and metadata to optimize YouTube channel growth",
    capabilities: [
      :content_analysis,
      :metadata_generation,
      :performance_prediction,
      :optimal_posting_time
    ],
    llm_config: %{
      model: "gpt-4o-mini",
      temperature: 0.7,
      json_response: true,
      json_schema: %{
        name: "content_optimization",
        schema: %{
          type: "object",
          properties: %{
            title: %{
              type: "string",
              description: "Optimized video title"
            },
            description: %{
              type: "string",
              description: "Generated SEO description"
            },
            tags: %{
              type: "array",
              items: %{type: "string"},
              description: "Optimized tags"
            },
            thumbnails_ideas: %{
              type: "array",
              items: %{type: "string"},
              description: "Thumbnail concepts"
            },
            engagement_analysis: %{
              type: "string",
              description: "Audience engagement summary"
            },
            trending_topics: %{
              type: "array",
              items: %{type: "string"},
              description: "Related trending topics"
            },
            content_recommendations: %{
              type: "array",
              items: %{type: "string"},
              description: "Ideas for future videos based on analysis"
            }
          },
          required: [
            "title",
            "description",
            "tags",
            "thumbnails_ideas",
            "engagement_analysis",
            "trending_topics",
            "content_recommendations"
          ]
        }
      },
      messages: [
        %{
          role: "system",
          content: """
          You are a YouTube Content Intelligence Agent. Given video details, channel metrics,
          and content topics, you provide optimized metadata and actionable insights.
          Your recommendations must be in valid JSON format.
          """
        }
      ]
    }

  require Logger
  require Lux.Python

  @doc """
  Generates metadata and content recommendations based on video context and historical performance.
  """
  def optimize_content(agent, video_context) do
    with {:ok, analysis} <-
           send_message(agent, """
           Analyze the following video context and provide optimizations:
           #{Jason.encode!(video_context, pretty: true)}

           Respond with the complete optimization JSON including ALL required fields.
           """) do
      {:ok, parse_json_response(analysis)}
    end
  end

  defp parse_json_response(analysis) when is_binary(analysis) do
    Jason.decode!(analysis, keys: :atoms)
  end

  defp parse_json_response(%Lux.Signal{payload: %{content: content}}) when is_map(content) do
    normalize_keys_to_atoms(content)
  end

  defp parse_json_response(%Lux.Signal{payload: %{content: content}}) when is_binary(content) do
    Jason.decode!(content, keys: :atoms)
  end

  defp parse_json_response(other) when is_map(other) do
    normalize_keys_to_atoms(other)
  end

  defp normalize_keys_to_atoms(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), normalize_keys_to_atoms(v)}
      {k, v} when is_atom(k) -> {k, normalize_keys_to_atoms(v)}
    end)
  end

  defp normalize_keys_to_atoms(list) when is_list(list) do
    Enum.map(list, &normalize_keys_to_atoms/1)
  end

  defp normalize_keys_to_atoms(other), do: other

  @doc """
  Clamps retention rate percentage strictly to the range [0.0, 100.0].
  """
  def clamp_retention(retention) when is_number(retention) do
    retention
    |> max(0.0)
    |> min(100.0)
  end

  def clamp_retention(_), do: 0.0

  @doc """
  Calculates metric summary from raw metric maps, clamping estimated_retention to [0.0, 100.0]
  and preventing negative or out-of-bounds metrics.
  """
  def calculate_metrics(metrics) when is_list(metrics) do
    sanitized = Enum.map(metrics, &sanitize_metric_item/1)

    retentions =
      sanitized
      |> Enum.map(& &1[:estimated_retention])
      |> Enum.reject(&is_nil/1)

    avg_retention =
      if retentions == [] do
        50.0
      else
        Enum.sum(retentions) / length(retentions)
      end

    %{
      metrics: sanitized,
      estimated_retention: clamp_retention(avg_retention)
    }
  end

  def calculate_metrics(_), do: %{metrics: [], estimated_retention: 50.0}

  defp sanitize_metric_item(m) when is_map(m) do
    raw_h = get_field(m, [:hour, "hour"], 17)
    raw_v = get_field(m, [:views, "views"], 0)
    raw_r = get_field(m, [:estimated_retention, "estimated_retention", :retention, "retention"], nil)

    h = raw_h |> to_int() |> max(0) |> min(23)
    v = raw_v |> to_int() |> max(0)

    ret =
      if is_nil(raw_r) do
        nil
      else
        raw_r |> to_float() |> clamp_retention()
      end

    %{
      hour: h,
      views: v,
      estimated_retention: ret
    }
  end

  defp sanitize_metric_item(_), do: %{hour: 17, views: 0, estimated_retention: 50.0}

  defp get_field(map, keys, default) do
    Enum.find_value(keys, default, fn k ->
      case Map.fetch(map, k) do
        {:ok, val} when not is_nil(val) -> val
        _ -> nil
      end
    end)
  end

  defp to_int(v) when is_integer(v), do: v
  defp to_int(v) when is_float(v), do: trunc(v)
  defp to_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {i, _} -> i
      :error -> 0
    end
  end
  defp to_int(_), do: 0

  defp to_float(v) when is_float(v), do: v
  defp to_float(v) when is_integer(v), do: v * 1.0
  defp to_float(v) when is_binary(v) do
    case Float.parse(v) do
      {f, _} -> f
      :error -> 0.0
    end
  end
  defp to_float(_), do: 0.0

  @doc """
  Uses Python machine learning models (simulated logic) via Lux.Python to predict the best
  posting time and view performance for a given channel's historical metrics.
  Clamps estimated_retention to [0.0..100.0] and prevents negative or out-of-bounds metrics.
  """
  def predict_performance(metrics) do
    Lux.Python.python variables: %{metrics: metrics} do
      ~PY'''
      import json

      if not metrics:
          result = {
              "optimal_posting_hour": 17,
              "predicted_views": 5000,
              "confidence_score": 0.5,
              "estimated_retention": 50.0
          }
      else:
          hour_views = {}
          total_views = 0
          retentions = []

          for m in metrics:
              if not isinstance(m, dict):
                  continue

              raw_h = 0
              raw_v = 0
              ret_val = None

              for k, val in m.items():
                  if isinstance(k, bytes):
                      k_str = k.decode('utf-8', errors='ignore')
                  else:
                      k_str = str(k)

                  k_str = k_str.lstrip(":")

                  if k_str == "hour":
                      raw_h = val
                  elif k_str == "views":
                      raw_v = val
                  elif k_str in ["estimated_retention", "retention"]:
                      ret_val = val

              try:
                  h_val = int(raw_h)
              except (ValueError, TypeError):
                  h_val = 0

              try:
                  v_val = int(raw_v)
              except (ValueError, TypeError):
                  v_val = 0

              # Clamp hour to valid 24h range [0, 23]
              h = max(0, min(23, h_val))
              # Prevent negative view metrics
              v = max(0, v_val)

              hour_views.setdefault(h, []).append(v)
              total_views += v

              if ret_val is not None:
                  try:
                      r = float(ret_val)
                      # Clamp estimated_retention to percentage [0..100]
                      r_clamped = max(0.0, min(100.0, r))
                      retentions.append(r_clamped)
                  except (ValueError, TypeError):
                      pass

          best_hour = 17
          max_avg = -1
          for h, vs in hour_views.items():
              avg = sum(vs) / len(vs) if vs else 0
              if avg > max_avg:
                  max_avg = avg
                  best_hour = h

          # Performance prediction calculation
          predicted_views = max(0, int(max_avg * 1.15)) if max_avg > 0 else 5000
          confidence_score = max(0.0, min(1.0, min(0.95, len(metrics) * 0.1)))

          if retentions:
              avg_retention = sum(retentions) / len(retentions)
              estimated_retention = max(0.0, min(100.0, round(avg_retention, 2)))
          else:
              estimated_retention = 50.0

          result = {
              "optimal_posting_hour": best_hour,
              "predicted_views": predicted_views,
              "confidence_score": confidence_score,
              "estimated_retention": estimated_retention
          }

      result
      '''
    end
  end
end
