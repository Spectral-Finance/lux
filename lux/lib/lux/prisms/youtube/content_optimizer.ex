defmodule Lux.Prisms.YouTube.ContentOptimizer do
  @moduledoc """
  Visual content optimization: thumbnails, end screens, cards, metadata.
  """

  @thumbnail_specs %{
    standard: %{width: 1280, height: 720, format: :jpg, max_size_kb: 2048},
    shorts: %{width: 1080, height: 1920, format: :jpg, max_size_kb: 2048}
  }

  @doc "Analyze and optimize thumbnail metadata."
  def optimize_thumbnail(params) do
    spec = Map.get(@thumbnail_specs, params[:type] || :standard, @thumbnail_specs.standard)
    issues = []

    issues = if params[:width] && params[:width] < spec.width,
      do: ["Resolution too low (#{params[:width]}x#{params[:height]}, need #{spec.width}x#{spec.height})" | issues],
      else: issues

    issues = if params[:file_size_kb] && params[:file_size_kb] > spec.max_size_kb,
      do: ["File too large (#{params[:file_size_kb]}KB, max #{spec.max_size_kb}KB)" | issues],
      else: issues

    issues = if !params[:has_text],
      do: ["Consider adding text overlay for CTR" | issues],
      else: issues

    issues = if !params[:has_face],
      do: ["Thumbnails with faces get 38% more clicks" | issues],
      else: issues

    score = max(0, 100 - length(issues) * 15)

    {:ok, %{
      score: score,
      issues: Enum.reverse(issues),
      spec: spec,
      optimized: issues == []
    }}
  end

  @doc "Generate end screen configuration."
  def generate_end_screen(params) do
    duration = params[:video_duration] || 600
    elements = []

    elements = if params[:subscribe] != false,
      do: [%{type: :subscribe, position: :bottom_right, start_time: duration - 20} | elements],
      else: elements

    elements = if params[:next_video],
      do: [%{type: :video, video_id: params[:next_video], position: :left, start_time: duration - 20} | elements],
      else: elements

    elements = if params[:playlist],
      do: [%{type: :playlist, playlist_id: params[:playlist], position: :right, start_time: duration - 15} | elements],
      else: elements

    {:ok, %{elements: Enum.reverse(elements), duration: 20}}
  end

  @doc "Generate cards for video."
  def generate_cards(params) do
    cards = params[:links] || []
    duration = params[:video_duration] || 600

    spaced = cards
    |> Enum.with_index()
    |> Enum.map(fn {card, idx} ->
      %{
        type: card[:type] || :video,
        target: card[:target],
        teaser_text: card[:teaser] || "Check this out!",
        time: trunc(duration * (idx + 1) / (length(cards) + 1))
      }
    end)

    {:ok, %{cards: spaced, count: length(spaced)}}
  end

  @doc "Optimize video metadata (title, description, tags)."
  def optimize_metadata(params) do
    title = params[:title] || ""
    description = params[:description] || ""
    tags = params[:tags] || []

    issues = []
    issues = if String.length(title) > 100, do: ["Title too long (max 100 chars)" | issues], else: issues
    issues = if String.length(title) < 20, do: ["Title too short (min 20 chars recommended)" | issues], else: issues
    issues = if String.length(description) < 100, do: ["Description too short (min 100 chars recommended)" | issues], else: issues
    issues = if length(tags) < 5, do: ["Add more tags (min 5 recommended)" | issues], else: issues
    issues = if length(tags) > 30, do: ["Too many tags (max 30)" | issues], else: issues

    score = max(0, 100 - length(issues) * 10)

    {:ok, %{score: score, issues: Enum.reverse(issues), title_length: String.length(title), tag_count: length(tags)}}
  end
end
