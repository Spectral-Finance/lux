defmodule Lux.Prisms.Youtube.ThumbnailSuggestionPrism do
  @moduledoc """
  A prism that generates optimized YouTube thumbnail suggestions based on
  video content, title, and performance data.

  Analyzes video metadata to suggest thumbnail compositions that maximize
  click-through rate (CTR) based on proven patterns in the niche.

  ## Examples

      iex> Lux.Prisms.Youtube.ThumbnailSuggestionPrism.run(%{
      ...>   video_title: "Building a DeFi Dashboard in 10 Minutes",
      ...>   category: "Technology",
      ...>   niche: "Web3 development",
      ...>   target_ctr: 0.08
      ...> })
      {:ok, %{suggestions: [...], color_palette: [...], text_overlays: [...]}}
  """

  use Lux.Prism,
    name: "YouTube Thumbnail Suggestion",
    description: "Generates optimized YouTube thumbnail compositions for maximum CTR",
    input_schema: %{
      type: :object,
      properties: %{
        video_title: %{
          type: :string,
          description: "Video title or working title"
        },
        category: %{
          type: :string,
          description: "Video category",
          default: "Technology"
        },
        niche: %{
          type: :string,
          description: "Content niche or subcategory"
        },
        key_elements: %{
          type: :array,
          items: %{type: :string},
          description: "Key visual elements to include"
        },
        style: %{
          type: :string,
          description: "Thumbnail style preference",
          enum: ["minimal", "bold", "professional", "casual", "gaming"],
          default: "bold"
        },
        face_included: %{
          type: :boolean,
          description: "Whether a face will be in the thumbnail",
          default: true
        }
      },
      required: ["video_title"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        suggestions: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              name: %{type: :string},
              description: %{type: :string},
              composition: %{type: :string},
              text_overlay: %{type: :string},
              color_scheme: %{type: :string}
            }
          }
        },
        color_palette: %{type: :array},
        recommended_dimensions: %{type: :string},
        best_practices: %{type: :array}
      }
    }

  @doc """
  Generates thumbnail suggestions based on video metadata.
  """
  def run(params) do
    video_title = Map.get(params, :video_title, params["video_title"])
    category = Map.get(params, :category, params["category"] || "Technology")
    niche = Map.get(params, :niche, params["niche"] || "")
    key_elements = Map.get(params, :key_elements, params["key_elements"] || [])
    style = Map.get(params, :style, params["style"] || "bold")
    face_included = Map.get(params, :face_included, params["face_included"] || true)

    suggestions = generate_suggestions(%{
      video_title: video_title,
      category: category,
      niche: niche,
      key_elements: key_elements,
      style: style,
      face_included: face_included
    })

    color_palette = get_color_palette(category, style)
    best_practices = get_best_practices(style)

    result = %{
      suggestions: suggestions,
      color_palette: color_palette,
      recommended_dimensions: "1280x720 (16:9 ratio)",
      best_practices: best_practices
    }

    {:ok, result}
  end

  defp generate_suggestions(params) do
    %{
      video_title: title,
      category: _category,
      niche: niche,
      key_elements: key_elements,
      style: style,
      face_included: face
    } = params

    # Extract key phrases from title
    title_words = title |> String.split() |> Enum.take(4) |> Enum.join(" ")

    [
      %{
        name: "Reaction Face + Title",
        description: "#{if face, do: "Expressive reaction face", else: "Dynamic scene"} on left, bold text overlay on right",
        composition: "Split layout: 40% visual / 60% text",
        text_overlay: String.upcase(title_words),
        color_scheme: get_style_colors(style)
      },
      %{
        name: "Before/After Comparison",
        description: "Side-by-side comparison showing transformation",
        composition: "Two-panel layout with arrow or divider",
        text_overlay: "BEFORE → AFTER",
        color_scheme: get_style_colors(style)
      },
      %{
        name: "Numbered List / Steps",
        description: "Large number with key concept text",
        composition: "Centered number with supporting elements",
        text_overlay: "#{length(key_elements) + 1} #{if length(key_elements) == 1, do: "STEP", else: "STEPS"}",
        color_scheme: get_style_colors(style)
      },
      %{
        name: "Question / Curiosity Gap",
        description: "Intriguing visual that raises questions",
        composition: "Full-bleed background with centered text",
        text_overlay: "WHY #{String.upcase(title_words)}?",
        color_scheme: get_style_colors(style)
      },
      %{
        name: "Result-Focused",
        description: "Show the end result or outcome prominently",
        composition: "Result screenshot/mockup as main visual",
        text_overlay: "I BUILT #{String.upcase(niche || "THIS")}",
        color_scheme: get_style_colors(style)
      }
    ]
  end

  defp get_color_palette(category, style) do
    base_palette = case style do
      "bold" ->
        ["#FF0000 (Red)", "#FFFFFF (White)", "#000000 (Black)", "#FFD700 (Gold)"]
      "minimal" ->
        ["#1A1A2E (Dark Navy)", "#E94560 (Accent Pink)", "#FFFFFF (White)"]
      "professional" ->
        ["#003049 (Dark Blue)", "#0077B6 (Blue)", "#00B4D8 (Light Blue)", "#FFFFFF (White)"]
      "casual" ->
        ["#FFB703 (Orange)", "#219EBC (Teal)", "#023047 (Dark Blue)", "#FB8500 (Bright Orange)"]
      "gaming" ->
        ["#7209B7 (Purple)", "#F72585 (Pink)", "#4CC9F0 (Cyan)", "#000000 (Black)"]
      _ ->
        ["#FF0000", "#FFFFFF", "#000000"]
    end

    base_palette
  end

  defp get_style_colors(style) do
    case style do
      "bold" -> "High contrast: Red/White/Black"
      "minimal" -> "Subtle: Dark Navy + single accent"
      "professional" -> "Trust: Blue tones + White"
      "casual" -> "Warm: Orange + Teal"
      "gaming" -> "Vibrant: Purple + Pink + Cyan"
      _ -> "High contrast recommended"
    end
  end

  defp get_best_practices(style) do
    [
      "Use 1280x720 resolution (minimum 640px wide)",
      "Keep text under 5 words for mobile readability",
      "Use high-contrast colors for visibility at small sizes",
      "Include a human face for 38% higher CTR (if applicable)",
      "Test thumbnail at 10% size to verify readability",
      "Maintain consistent branding across videos",
      "Use the rule of thirds for composition",
      "Avoid cluttered backgrounds and too many elements"
    ]
  end
end
