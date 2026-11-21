defmodule Lux.Prisms.YouTube.OptimizeTags do
  @moduledoc """
  A prism that extracts, ranks, and packs YouTube tags from text (lux issue #69
  — "Tag optimization").

  Pure and deterministic. Ranks candidate single-word tags by a frequency +
  length-weight heuristic (boosting the target keyword), expands with common
  long-tail phrase variants, and packs them within YouTube's 500-character
  tag budget and a max tag count.

  ## Examples
      iex> OptimizeTags.handler(%{text: "Elixir liveview tutorial for beginners", keyword: "elixir"}, %{name: "Agent"})
      {:ok, %{tags: ["elixir", "elixir tutorial", "elixir tips"], tag_string: "elixir, elixir tutorial, elixir tips"}}
  """

  use Lux.Prism,
    name: "Optimize YouTube Tags",
    description: "Extracts, ranks, and budget-packs YouTube tags from text",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "Source text (title + description/transcript)"},
        keyword: %{type: :string, description: "Optional target keyword to boost"},
        max_tags: %{
          type: :integer,
          description: "Maximum number of tags to return",
          default: 15,
          minimum: 1,
          maximum: 50
        }
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        tags: %{type: :array, description: "Packed, ranked tag list"},
        tag_string: %{type: :string, description: "Comma-joined tag string for the API"},
        char_count: %{type: :integer, description: "Total characters used"},
        count: %{type: :integer, description: "Number of tags"}
      },
      required: ["tags", "tag_string"]
    }

  alias Lux.Prisms.YouTube.Util

  @max_total_chars 500

  def handler(params, _agent) do
    text = Map.get(params, :text, "")
    keyword = Map.get(params, :keyword)
    max_tags = Map.get(params, :max_tags, 15)

    ranked = extract(text, keyword)
    expanded = expand(ranked, keyword)
    packed = pack(expanded, max_tags)

    char_count = packed |> Enum.join(", ") |> String.length()

    result = %{
      tags: packed,
      tag_string: Enum.join(packed, ", "),
      char_count: char_count,
      count: length(packed)
    }

    {:ok, result}
  end

  defp extract(text, keyword) do
    counts =
      text
      |> Util.content_words()
      |> Enum.frequencies()

    counts =
      if keyword && keyword != "" do
        keyword
        |> Util.content_words()
        |> Enum.reduce(counts, fn w, acc -> Map.update(acc, w, 5, &(&1 + 5)) end)
      else
        counts
      end

    counts
    |> Enum.map(fn {word, freq} ->
      length_weight = min(String.length(word), 12) / 12.0
      score = freq * (0.5 + length_weight)
      {word, score}
    end)
    |> Enum.sort_by(fn {_w, score} -> score end, :desc)
    |> Enum.map(&elem(&1, 0))
  end

  defp expand([], _keyword), do: []

  defp expand(base, keyword) do
    kw = keyword || List.first(base, "")

    phrases =
      if kw != "" do
        [
          kw,
          "#{kw} tutorial",
          "#{kw} tips",
          "how to #{kw}",
          "#{kw} 2026",
          "best #{kw}",
          "#{kw} guide"
        ]
      else
        []
      end

    (phrases ++ base)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp pack(tags, max_tags) do
    tags
    |> Enum.reduce_while({[], 0}, fn tag, {acc, total} ->
      if length(acc) >= max_tags do
        {:halt, {acc, total}}
      else
        add = String.length(tag) + if(acc == [], do: 0, else: 1)

        if total + add > @max_total_chars do
          {:halt, {acc, total}}
        else
          {:cont, {acc ++ [tag], total + add}}
        end
      end
    end)
    |> elem(0)
  end
end
