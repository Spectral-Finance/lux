defmodule Lux.Prisms.YouTube.Intelligence.MetadataGenerator do
  @moduledoc """
  Prism for automated metadata generation for YouTube videos.

  Generates optimized titles, descriptions, tags, thumbnails text,
  and chapter markers based on video content and niche analysis.
  """

  use Lux.Prism,
    name: "YouTube Metadata Generator",
    description: "Auto-generate optimized video metadata",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["description", "chapters", "cards", "end_screen"]},
        topic: %{type: :string, description: "Video topic"},
        key_points: %{type: :array, description: "Key points covered in the video"},
        niche: %{type: :string},
        duration_minutes: %{type: :number},
        links: %{type: :object, description: "Related links to include"},
        social_links: %{type: :object, description: "Social media links"}
      },
      required: ["action", "topic"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        generated: %{type: :object}
      }
    }

  @impl true
  def handler(params, _opts) do
    action = params[:action] || params["action"]

    case action do
      "description" -> generate_description(params)
      "chapters" -> generate_chapters(params)
      "cards" -> suggest_cards(params)
      "end_screen" -> suggest_end_screen(params)
      _ -> {:error, "Unknown action: #{action}"}
    end
  end

  defp generate_description(params) do
    topic = params[:topic] || params["topic"]
    key_points = params[:key_points] || params["key_points"] || []
    niche = params[:niche] || params["niche"] || ""
    links = params[:links] || params["links"] || %{}
    social = params[:social_links] || params["social_links"] || %{}

    points_text =
      key_points
      |> Enum.with_index(1)
      |> Enum.map(fn {point, i} -> "#{i}. #{point}" end)
      |> Enum.join("\n")

    links_text =
      links
      |> Enum.map(fn {label, url} -> "🔗 #{label}: #{url}" end)
      |> Enum.join("\n")

    social_text =
      social
      |> Enum.map(fn {platform, url} -> "#{String.capitalize(to_string(platform))}: #{url}" end)
      |> Enum.join("\n")

    description = """
    #{topic}

    In this video, we cover everything you need to know about #{String.downcase(topic)}.

    #{if points_text != "", do: "📋 What's covered:\n#{points_text}\n", else: ""}
    #{if links_text != "", do: "📎 Resources:\n#{links_text}\n", else: ""}
    #{if social_text != "", do: "🌐 Follow me:\n#{social_text}\n", else: ""}
    ---
    🔔 Subscribe and turn on notifications!
    👍 Like this video if you found it helpful
    💬 Comment below with your questions

    ##{String.replace(niche, " ", "")} ##{String.replace(topic, " ", "")} #youtube
    """
    |> String.trim()

    {:ok, %{
      description: description,
      length: String.length(description),
      has_cta: true,
      has_hashtags: true,
      has_timestamps: false
    }}
  end

  defp generate_chapters(params) do
    key_points = params[:key_points] || params["key_points"] || []
    duration = params[:duration_minutes] || params["duration_minutes"] || 10

    if length(key_points) < 2 do
      {:ok, %{chapters: [], note: "Need at least 2 key points to generate chapters"}}
    else
      interval = duration / (length(key_points) + 1)

      chapters =
        [{0, "Introduction"} | Enum.with_index(key_points, 1)]
        |> Enum.map(fn
          {0, label} ->
            %{timestamp: "0:00", label: label}

          {point, idx} ->
            minutes = round(idx * interval)
            secs = rem(round(idx * interval * 60), 60)
            %{timestamp: "#{minutes}:#{String.pad_leading("#{secs}", 2, "0")}", label: point}
        end)

      text =
        chapters
        |> Enum.map(fn c -> "#{c.timestamp} #{c.label}" end)
        |> Enum.join("\n")

      {:ok, %{
        chapters: chapters,
        text: text,
        count: length(chapters)
      }}
    end
  end

  defp suggest_cards(params) do
    key_points = params[:key_points] || params["key_points"] || []
    duration = params[:duration_minutes] || params["duration_minutes"] || 10

    cards =
      key_points
      |> Enum.take(5)
      |> Enum.with_index(1)
      |> Enum.map(fn {point, idx} ->
        timestamp_sec = round(idx / (length(key_points) + 1) * duration * 60)

        %{
          type: "video",
          timestamp_seconds: timestamp_sec,
          teaser_text: "Learn more: #{point}",
          suggestion: "Link to related video about #{point}"
        }
      end)

    {:ok, %{
      cards: cards,
      count: length(cards),
      max_allowed: 5
    }}
  end

  defp suggest_end_screen(params) do
    topic = params[:topic] || params["topic"]
    niche = params[:niche] || params["niche"] || ""
    duration = params[:duration_minutes] || params["duration_minutes"] || 10

    start_time = max(round((duration - 0.5) * 60), 30)

    {:ok, %{
      elements: [
        %{type: "subscribe", position: "bottom_right", start_seconds: start_time},
        %{type: "best_for_viewer", position: "bottom_left", start_seconds: start_time},
        %{type: "playlist", position: "top_right", start_seconds: start_time,
          suggestion: "#{niche} playlist"}
      ],
      duration_seconds: 20,
      start_seconds: start_time,
      cta: "If you enjoyed learning about #{topic}, check out these related videos!"
    }}
  end
end
