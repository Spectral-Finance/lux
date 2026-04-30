defmodule Lux.Beams.YoutubeContentPipeline do
  @moduledoc """
  A beam that orchestrates the complete YouTube content creation pipeline.

  Chains together lenses (data collection) and prisms (content transformation)
  to create an end-to-end workflow for YouTube content creation:

  1. Collect video analytics and comments data
  2. Generate optimized scripts based on topic and audience
  3. Suggest thumbnail compositions
  4. Optimize metadata (title, description, tags)
  5. Produce a complete content package

  ## Example

      iex> Lux.Beams.YoutubeContentPipeline.run(%{
      ...>   video_id: "dQw4w9WgXcQ",
      ...>   topic: "Building a DeFi Dashboard",
      ...>   target_audience: "Web3 developers",
      ...>   duration_minutes: 10
      ...> })
      {:ok, %{content_package: %{...}, analytics: %{...}, metadata: %{...}}}
  """

  use Lux.Beam,
    name: "YouTube Content Pipeline",
    description: "End-to-end YouTube content creation pipeline: analytics → script → thumbnail → metadata",
    input_schema: %{
      type: :object,
      properties: %{
        video_id: %{
          type: :string,
          description: "YouTube video ID for analytics collection (optional for new videos)"
        },
        topic: %{
          type: :string,
          description: "Main topic of the video content"
        },
        target_audience: %{
          type: :string,
          description: "Target audience for the content"
        },
        duration_minutes: %{
          type: :integer,
          description: "Target video duration in minutes",
          default: 10
        },
        tone: %{
          type: :string,
          description: "Content tone",
          enum: ["educational", "entertaining", "professional", "casual"],
          default: "educational"
        },
        key_points: %{
          type: :array,
          items: %{type: :string},
          description: "Key points to cover"
        },
        target_keywords: %{
          type: :array,
          items: %{type: :string},
          description: "Target SEO keywords"
        },
        style: %{
          type: :string,
          description: "Thumbnail style",
          enum: ["minimal", "bold", "professional", "casual", "gaming"],
          default: "bold"
        }
      },
      required: ["topic"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        content_package: %{
          type: :object,
          properties: %{
            script: %{type: :string},
            sections: %{type: :array},
            hooks: %{type: :array},
            suggested_ctas: %{type: :array}
          }
        },
        thumbnail: %{
          type: :object,
          properties: %{
            suggestions: %{type: :array},
            color_palette: %{type: :array},
            best_practices: %{type: :array}
          }
        },
        metadata: %{
          type: :object,
          properties: %{
            optimized_title: %{type: :string},
            title_alternatives: %{type: :array},
            optimized_description: %{type: :string},
            tags: %{type: :array},
            seo_score: %{type: :number}
          }
        },
        analytics: %{
          type: :object,
          description: "Video analytics (if video_id provided)"
        },
        pipeline_status: %{
          type: :string,
          enum: ["success", "partial", "error"]
        }
      }
    }

  @doc """
  Runs the complete YouTube content pipeline.
  """
  def run(params) do
    topic = Map.get(params, :topic, params["topic"])
    target_audience = Map.get(params, :target_audience, params["target_audience"] || "general audience")
    duration_minutes = Map.get(params, :duration_minutes, params["duration_minutes"] || 10)
    tone = Map.get(params, :tone, params["tone"] || "educational")
    key_points = Map.get(params, :key_points, params["key_points"] || [])
    target_keywords = Map.get(params, :target_keywords, params["target_keywords"] || [])
    style = Map.get(params, :style, params["style"] || "bold")
    video_id = Map.get(params, :video_id, params["video_id"])

    # Step 1: Collect analytics (if video_id provided)
    analytics_result = if video_id do
      collect_analytics(video_id)
    else
      {:ok, %{message: "No video_id provided, skipping analytics collection"}}
    end

    # Step 2: Generate script
    script_result = generate_script(%{
      topic: topic,
      target_audience: target_audience,
      duration_minutes: duration_minutes,
      tone: tone,
      key_points: key_points
    })

    # Step 3: Generate thumbnail suggestions
    thumbnail_result = generate_thumbnail(%{
      video_title: extract_title_from_script(script_result, topic),
      style: style,
      niche: target_audience
    })

    # Step 4: Optimize metadata
    metadata_result = optimize_metadata(%{
      topic: topic,
      target_keywords: target_keywords,
      script: script_result
    })

    # Compile results
    {pipeline_status, content_package, thumbnail, metadata, analytics} = compile_results(%{
      analytics: analytics_result,
      script: script_result,
      thumbnail: thumbnail_result,
      metadata: metadata_result
    })

    result = %{
      content_package: content_package,
      thumbnail: thumbnail,
      metadata: metadata,
      analytics: analytics,
      pipeline_status: pipeline_status
    }

    {:ok, result}
  end

  defp collect_analytics(video_id) do
    # Collect video info
    video_info = Lux.Lenses.Youtube.VideoInfoLens.focus(%{video_id: video_id})

    # Collect analytics
    analytics = Lux.Lenses.Youtube.VideoAnalyticsLens.focus(%{
      video_id: video_id,
      start_date: Date.utc_today() |> Date.add(-30) |> Date.to_iso8601(),
      end_date: Date.utc_today() |> Date.to_iso8601()
    })

    # Collect comments for sentiment analysis
    comments = Lux.Lenses.Youtube.CommentsLens.focus(%{
      video_id: video_id,
      max_results: 20,
      order: "relevance"
    })

    {:ok, %{
      video_info: video_info,
      analytics: analytics,
      comments: comments
    }}
  rescue
    error -> {:error, "Analytics collection failed: #{inspect(error)}"}
  end

  defp generate_script(params) do
    %{topic: topic, target_audience: audience, duration_minutes: duration, tone: tone, key_points: points} = params

    case Lux.Prisms.Youtube.ScriptGeneratorPrism.run(%{
      topic: topic,
      target_audience: audience,
      duration_minutes: duration,
      tone: tone,
      key_points: points,
      include_hooks: true,
      include_cta: true
    }) do
      {:ok, script_data} -> {:ok, script_data}
      {:error, reason} -> {:error, reason}
    end
  end

  defp generate_thumbnail(params) do
    %{video_title: title, style: style, niche: niche} = params

    case Lux.Prisms.Youtube.ThumbnailSuggestionPrism.run(%{
      video_title: title,
      style: style,
      niche: niche,
      face_included: true
    }) do
      {:ok, thumbnail_data} -> {:ok, thumbnail_data}
      {:error, reason} -> {:error, reason}
    end
  end

  defp optimize_metadata(params) do
    %{topic: topic, target_keywords: keywords, script: script_result} = params

    # Extract title from script if available
    script_title = case script_result do
      {:ok, %{sections: [%{name: first_section} | _]}} -> first_section
      _ -> topic
    end

    case Lux.Prisms.Youtube.MetadataOptimizerPrism.run(%{
      topic: topic,
      existing_title: script_title,
      target_keywords: keywords,
      include_timestamps: true
    }) do
      {:ok, metadata} -> {:ok, metadata}
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_title_from_script(result, default) do
    case result do
      {:ok, %{sections: [%{name: name} | _]}} -> name
      {:ok, %{script: script}} when is_binary(script) ->
        script |> String.split("\n") |> Enum.find(&(&1 |> String.starts_with?("#")) || false) || default
      _ -> default
    end
  end

  defp compile_results(results) do
    %{analytics: analytics, script: script, thumbnail: thumbnail, metadata: metadata} = results

    # Determine pipeline status
    statuses = [analytics, script, thumbnail, metadata]
    success_count = Enum.count(statuses, &(elem(&1, 0) == :ok))

    pipeline_status = case success_count do
      4 -> "success"
      count when count >= 2 -> "partial"
      _ -> "error"
    end

    # Extract successful results
    content_package = case script do
      {:ok, data} -> %{
        script: data[:script] || data["script"] || "",
        sections: data[:sections] || data["sections"] || [],
        hooks: data[:hooks] || data["hooks"] || [],
        suggested_ctas: data[:suggested_ctas] || data["suggested_ctas"] || []
      }
      _ -> %{script: "", sections: [], hooks: [], suggested_ctas: []}
    end

    thumbnail_data = case thumbnail do
      {:ok, data} -> %{
        suggestions: data[:suggestions] || data["suggestions"] || [],
        color_palette: data[:color_palette] || data["color_palette"] || [],
        best_practices: data[:best_practices] || data["best_practices"] || []
      }
      _ -> %{suggestions: [], color_palette: [], best_practices: []}
    end

    metadata_data = case metadata do
      {:ok, data} -> %{
        optimized_title: data[:optimized_title] || data["optimized_title"] || "",
        title_alternatives: data[:title_alternatives] || data["title_alternatives"] || [],
        optimized_description: data[:optimized_description] || data["optimized_description"] || "",
        tags: data[:tags] || data["tags"] || [],
        seo_score: data[:seo_score] || data["seo_score"] || 0.0
      }
      _ -> %{optimized_title: "", title_alternatives: [], optimized_description: "", tags: [], seo_score: 0.0}
    end

    analytics_data = case analytics do
      {:ok, data} -> data
      _ -> %{error: "Analytics collection failed"}
    end

    {pipeline_status, content_package, thumbnail_data, metadata_data, analytics_data}
  end
end
