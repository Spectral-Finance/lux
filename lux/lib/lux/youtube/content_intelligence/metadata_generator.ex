defmodule Lux.YouTube.ContentIntelligence.MetadataGenerator do
  @moduledoc """
  Generates SEO-optimized descriptions, formatted chapter timestamps,
  and high-relevance tag packages conforming to YouTube algorithm specifications.
  """

  @max_tags_character_length 495

  @type chapter :: %{timestamp: String.t(), title: String.t()}

  @type metadata_package :: %{
          description: String.t(),
          tags_list: list(String.t()),
          tags_comma_separated: String.t(),
          tags_total_characters: non_neg_integer(),
          hashtags: list(String.t()),
          chapters_formatted: String.t()
        }

  @doc """
  Builds a full metadata package from video concept details.
  """
  @spec generate_package(map()) :: metadata_package()
  def generate_package(params) when is_map(params) do
    title = Map.get(params, :title, Map.get(params, "title", "Video Guide"))
    niche = Map.get(params, :niche, Map.get(params, "niche", "Technology"))
    summary = Map.get(params, :summary, Map.get(params, "summary", "In this video we break down everything you need to know."))
    chapters = Map.get(params, :chapters, Map.get(params, "chapters", default_chapters()))
    links = Map.get(params, :links, Map.get(params, "links", []))
    keywords = Map.get(params, :keywords, Map.get(params, "keywords", [niche]))

    formatted_chapters = format_chapters(chapters)
    hashtags = generate_hashtags(keywords, niche)
    description = build_description(title, summary, formatted_chapters, links, hashtags)
    {tags, tags_str, char_count} = generate_tags(keywords, niche, title)

    %{
      description: description,
      tags_list: tags,
      tags_comma_separated: tags_str,
      tags_total_characters: char_count,
      hashtags: hashtags,
      chapters_formatted: formatted_chapters
    }
  end

  @doc """
  Generates optimized tags and ensures the total character length stays within 500 characters.
  """
  @spec generate_tags(list(String.t()), String.t(), String.t()) :: {list(String.t()), String.t(), non_neg_integer()}
  def generate_tags(keywords, niche, title) do
    # Extract words from title
    title_words =
      title
      |> String.downcase()
      |> String.replace(~r/[^\w\s]/, "")
      |> String.split(~r/\s+/, trim: true)
      |> Enum.reject(&(&1 in ~w(the a an and or in on at to for of how what why with)))

    raw_tags =
      [
        title,
        niche,
        "#{niche} tutorial",
        "learn #{niche}",
        "#{niche} guide 2026",
        "how to build #{niche}",
        "best #{niche} tips"
      ] ++
        keywords ++
        Enum.map(keywords, &"#{&1} explained") ++
        Enum.map(keywords, &"#{&1} architecture") ++
        title_words

    # Deduplicate and fit within 495 chars
    unique_tags =
      raw_tags
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq_by(&String.downcase/1)

    {fitted_tags, _} =
      Enum.reduce(unique_tags, {[], 0}, fn tag, {acc, cur_len} ->
        added_len = String.length(tag) + if(cur_len > 0, do: 1, else: 0)

        if cur_len + added_len <= @max_tags_character_length do
          {[tag | acc], cur_len + added_len}
        else
          {acc, cur_len}
        end
      end)

    final_tags = Enum.reverse(fitted_tags)
    joined_tags = Enum.join(final_tags, ",")

    {final_tags, joined_tags, String.length(joined_tags)}
  end

  defp format_chapters(chapters) when is_list(chapters) do
    Enum.map_join(chapters, "\n", fn ch ->
      ts = Map.get(ch, :timestamp, Map.get(ch, "timestamp", "00:00"))
      t = Map.get(ch, :title, Map.get(ch, "title", "Chapter"))
      "#{ts} - #{t}"
    end)
  end

  defp default_chapters do
    [
      %{timestamp: "00:00", title: "Introduction & Overview"},
      %{timestamp: "01:15", title: "Core Concepts & Architecture"},
      %{timestamp: "04:30", title: "Step-by-Step Implementation"},
      %{timestamp: "09:45", title: "Live Demo & Testing"},
      %{timestamp: "12:30", title: "Key Takeaways & Next Steps"}
    ]
  end

  defp generate_hashtags(keywords, niche) do
    base = [niche | keywords]

    base
    |> Enum.map(fn kw ->
      "#" <> (kw |> String.replace(~r/[^\w]/, "") |> String.capitalize())
    end)
    |> Enum.take(3)
  end

  defp build_description(title, summary, chapters_str, links, hashtags) do
    links_section =
      if Enum.empty?(links) do
        "🔔 Subscribe for more high-impact engineering breakdowns!\n💻 Documentation & Code: https://github.com/Spectral-Finance/lux"
      else
        Enum.map_join(links, "\n", fn link -> "🔗 #{link}" end)
      end

    hashtags_str = Enum.join(hashtags, " ")

    """
    #{title}

    #{summary}

    ⏱️ CHAPTERS:
    #{chapters_str}

    📌 RESOURCES & LINKS:
    #{links_section}

    #{hashtags_str}
    """
    |> String.trim()
  end
end
