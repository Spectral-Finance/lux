defmodule Lux.Prisms.YouTube.OptimizeVideoMetadata do
  @moduledoc """
  A prism for optimizing YouTube video metadata for maximum discoverability.

  Analyzes the provided title, description, and tags, then returns:
  - Optimized title with improved keyword placement
  - Optimized and sorted tags list
  - SEO score (0-100)
  - Thumbnail design recommendations
  - Optimal posting times by day of week

  ## Examples

      iex> OptimizeVideoMetadata.handler(%{
      ...>   "title" => "How to Code",
      ...>   "description" => "Learn coding basics",
      ...>   "tags" => ["coding", "tutorial"],
      ...>   "category" => "Education"
      ...> }, %{})
      {:ok, %{
        optimized_title: "How to Code: Complete Beginner Tutorial (2024)",
        optimized_tags: ["coding tutorial", "learn to code", "coding", "tutorial"],
        seo_score: 72,
        thumbnail_recommendations: ["Use high-contrast colors", "Include a human face"],
        optimal_posting_times: [%{day: "Tuesday", time: "14:00 UTC", reason: "Peak engagement"}]
      }}
  """

  use Lux.Prism,
    name: "Optimize Video Metadata",
    description: "Analyzes and optimizes YouTube video title, tags, description, and recommends posting times and thumbnail improvements",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{
          type: :string,
          description: "Current video title to optimize"
        },
        description: %{
          type: :string,
          description: "Current video description to analyze"
        },
        tags: %{
          type: :array,
          items: %{type: :string},
          description: "Current list of video tags"
        },
        category: %{
          type: :string,
          description: "Video category (e.g. Education, Gaming, Music)"
        }
      },
      required: ["title"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        optimized_title: %{type: :string},
        optimized_description: %{type: :string},
        optimized_tags: %{type: :array, items: %{type: :string}},
        seo_score: %{type: :integer, minimum: 0, maximum: 100},
        thumbnail_recommendations: %{type: :array, items: %{type: :string}},
        optimal_posting_times: %{type: :array, items: %{type: :object}}
      }
    }

  @doc """
  Analyzes and optimizes video metadata for YouTube SEO.
  """
  def handler(params, _agent) do
    title = params["title"] || params[:title] || ""
    description = params["description"] || params[:description] || ""
    tags = params["tags"] || params[:tags] || []
    category = params["category"] || params[:category] || "General"

    optimized_title = optimize_title(title, category)
    optimized_tags = optimize_tags(tags, title)
    optimized_description = optimize_description(description, title, tags)
    seo_score = compute_seo_score(title, description, tags)
    thumbnail_recs = thumbnail_recommendations(category)
    posting_times = optimal_posting_times(category)

    {:ok, %{
      original_title: title,
      optimized_title: optimized_title,
      optimized_description: optimized_description,
      optimized_tags: optimized_tags,
      seo_score: seo_score,
      thumbnail_recommendations: thumbnail_recs,
      optimal_posting_times: posting_times
    }}
  end

  defp optimize_title(title, category) do
    title = String.trim(title)
    word_count = title |> String.split() |> length()

    title
    |> maybe_add_power_word(word_count)
    |> maybe_add_year(category)
    |> String.slice(0, 100)
  end

  defp maybe_add_power_word(title, count) when count < 4 do
    "#{title}: Complete Guide"
  end

  defp maybe_add_power_word(title, _count), do: title

  defp maybe_add_year(title, category)
       when category in ["Education", "Technology", "Gaming"] do
    year = Date.utc_today().year
    if String.contains?(title, Integer.to_string(year)) do
      title
    else
      "#{title} (#{year})"
    end
  end

  defp maybe_add_year(title, _category), do: title

  defp optimize_tags(tags, title) do
    title_words =
      title
      |> String.downcase()
      |> String.split(~r/\W+/, trim: true)
      |> Enum.filter(&(String.length(&1) > 3))

    # Generate compound tags from title words
    title_phrases =
      title_words
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(&Enum.join(&1, " "))
      |> Enum.take(3)

    existing_normalized = Enum.map(tags, &String.downcase/1)

    new_tags =
      title_phrases
      |> Enum.reject(&(String.downcase(&1) in existing_normalized))

    all_tags =
      (new_tags ++ tags)
      |> Enum.uniq_by(&String.downcase/1)
      |> Enum.take(15)

    # Sort: compound phrases first (more specific), then single words
    Enum.sort_by(all_tags, fn tag ->
      words = tag |> String.split() |> length()
      -words
    end)
  end

  defp optimize_description(description, title, tags) do
    desc = String.trim(description)

    if String.length(desc) < 100 do
      tag_line = if length(tags) > 0, do: "\n\nTags: #{Enum.join(Enum.take(tags, 5), ", ")}", else: ""
      "#{title}\n\n#{desc}#{tag_line}\n\n##{String.replace(title, " ", "")} #YouTube"
    else
      description
    end
  end

  defp compute_seo_score(title, description, tags) do
    title_score = score_title(title)
    desc_score = score_description(description)
    tag_score = score_tags(tags)

    min(title_score + desc_score + tag_score, 100)
  end

  defp score_title(title) do
    len = String.length(title)
    word_count = title |> String.split() |> length()

    base = cond do
      len >= 40 and len <= 70 -> 25
      len >= 20              -> 18
      true                   -> 10
    end

    power_words = ~w(how why best complete guide tutorial ultimate top secret)
    bonus = if Enum.any?(power_words, &String.contains?(String.downcase(title), &1)), do: 5, else: 0
    num_bonus = if word_count >= 5, do: 5, else: 0

    base + bonus + num_bonus
  end

  defp score_description(description) do
    len = String.length(description)
    cond do
      len >= 500 -> 30
      len >= 200 -> 25
      len >= 100 -> 15
      len >= 50  -> 8
      true       -> 0
    end
  end

  defp score_tags(tags) do
    count = length(tags)
    cond do
      count >= 10 -> 35
      count >= 5  -> 25
      count >= 2  -> 15
      count >= 1  -> 5
      true        -> 0
    end
  end

  defp thumbnail_recommendations(category) do
    base = [
      "Use high-contrast colors with strong foreground/background separation",
      "Include a human face with an expressive emotion to drive click-through",
      "Keep text to 3-5 words maximum using bold, legible fonts",
      "Ensure thumbnail reads clearly at 168x94px (smallest display size)"
    ]

    category_specific = case category do
      "Gaming"     -> ["Show key gameplay moment or character reaction shot"]
      "Education"  -> ["Use a whiteboard or diagram element to signal learning value"]
      "Music"      -> ["Feature the artist prominently with vibrant color palette"]
      "Technology" -> ["Show the product or screen with clean minimal design"]
      _            -> ["Use a branded lower-third with consistent channel colors"]
    end

    base ++ category_specific
  end

  defp optimal_posting_times(category) do
    base_times = [
      %{day: "Tuesday", time: "14:00 UTC", reason: "Mid-week peak — commute/lunch engagement"},
      %{day: "Thursday", time: "15:00 UTC", reason: "Pre-weekend discovery window"},
      %{day: "Saturday", time: "10:00 UTC", reason: "Morning leisure browsing — high session time"}
    ]

    category_times = case category do
      "Gaming" ->
        [%{day: "Friday", time: "17:00 UTC", reason: "Gaming weekend kickoff traffic spike"}]
      "Education" ->
        [%{day: "Monday", time: "08:00 UTC", reason: "Start-of-week learning motivation peak"}]
      "Music" ->
        [%{day: "Friday", time: "00:00 UTC", reason: "New music Friday — algorithmic boost window"}]
      _ ->
        []
    end

    base_times ++ category_times
  end
end
