defmodule Lux.YouTube.ContentIntelligence.MetadataGenerator do
  @moduledoc """
  Automated metadata generation for YouTube content intelligence.

  Provides SEO description builder with formatted chapter timestamps,
  and character-bounded tags (<495 chars).
  """

  @doc """
  Generates SEO-optimized metadata for a video.

  ## Parameters

    * `video_topic` - Main topic of the video
    * `video_description` - Base description text
    * `chapters` - List of %{start_time, title} maps for chapter timestamps
    * `keywords` - List of keyword strings for tags

  ## Returns

    * `{:ok, result}` - Generated metadata
    * `{:error, reason}` - If input is invalid
  """
  def generate(input) when is_map(input) do
    with {:ok, validated} <- validate_input(input) do
      seo_description = build_seo_description(validated.video_topic, validated.video_description)
      chapter_timestamps = format_chapter_timestamps(validated.chapters)
      tags = generate_tags_list(validated.keywords)

      {:ok, %{
        seo_description: seo_description,
        chapter_timestamps: chapter_timestamps,
        tags: tags,
        tags_character_count: String.length(Enum.join(tags, ",")),
        tags_within_limit: String.length(Enum.join(tags, ",")) < 495
      }}
    end
  end

  def generate(_input), do: {:error, :invalid_input}

  @doc """
  Builds an SEO-optimized description from topic and base text.
  """
  def seo_description(video_topic, video_description) when is_binary(video_topic) and is_binary(video_description) do
    build_seo_description(video_topic, video_description)
  end

  def seo_description(_, _), do: {:error, :invalid_input}

  @doc """
  Formats chapter timestamps for YouTube description.
  """
  def format_chapters(chapters) when is_list(chapters) do
    format_chapter_timestamps(chapters)
  end

  def format_chapters(_), do: {:error, :invalid_input}

  @doc """
  Generates character-bounded tags from keywords.
  """
  def generate_tags(keywords) when is_list(keywords) do
    generate_tags_list(keywords)
  end

  def generate_tags(_), do: {:error, :invalid_input}

  @doc """
  Checks if tags are within the 495 character YouTube limit.
  """
  def tags_within_limit?(tags) when is_list(tags) do
    String.length(Enum.join(tags, ",")) < 495
  end

  def tags_within_limit?(_), do: {:error, :invalid_input}

  # Private helpers

  defp validate_input(input) do
    required = [:video_topic, :video_description]

    missing = Enum.filter(required, fn key -> not Map.has_key?(input, key) end)

    if missing != [] do
      {:error, {:missing_fields, missing}}
    else
      cond do
        not is_binary(input.video_topic) -> {:error, {:invalid_value, :video_topic}}
        not is_binary(input.video_description) -> {:error, {:invalid_value, :video_description}}
        true ->
          {:ok,
           input
           |> Map.put(:chapters, Map.get(input, :chapters, []))
           |> Map.put(:keywords, Map.get(input, :keywords, []))}
      end
    end
  end

  defp build_seo_description(topic, base_description) do
    "#{topic} - #{base_description}

Discover everything you need to know about #{topic} in this comprehensive video.
We cover the essentials, share expert tips, and help you master #{topic}.

#YouTube #{String.replace(topic, " ", "")} #Tutorial #Guide #HowTo"
  end

  defp format_chapter_timestamps(chapters) do
    Enum.map(chapters, fn chapter ->
      start_time = Map.get(chapter, :start_time, 0)
      title = Map.get(chapter, :title, "Chapter")
      "#{format_timestamp(start_time)} - #{title}"
    end)
  end

  defp format_timestamp(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    secs = rem(seconds, 60)

    if hours > 0 do
      "#{hours}:#{pad(minutes)}:#{pad(secs)}"
    else
      "#{minutes}:#{pad(secs)}"
    end
  end

  defp pad(n), do: String.pad_leading(to_string(n), 2, "0")

  defp generate_tags_list(keywords) do
    # YouTube tag limit is 495 characters total
    tags = Enum.map(keywords, fn kw ->
      String.trim(kw)
    end)
    |> Enum.uniq()

    # Accumulate tags within 495 char limit
    {acc, _current_length} =
      Enum.reduce(tags, {[], 0}, fn tag, {acc, current_length} ->
        tag_length = String.length(tag)
        separator_length = if length(acc) > 0, do: 1, else: 0

        if current_length + tag_length + separator_length <= 495 do
          {[tag | acc], current_length + tag_length + separator_length}
        else
          {acc, current_length}
        end
      end)

    Enum.reverse(acc)
  end
end