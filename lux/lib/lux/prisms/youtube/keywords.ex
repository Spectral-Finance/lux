defmodule Lux.Prisms.YouTube.Keywords do
  @moduledoc """
  A prism that extracts ranked keywords from a video title or a batch of titles
  (lux issue #73 — "YouTube Prism implementation").

  Pure and deterministic: given a single `title` (or a list of `titles`) it
  tokenises, drops stopwords and short tokens, and returns the top-N keywords
  ranked by descending frequency with ties broken alphabetically. When given a
  batch it also reports the total number of titles analysed and the aggregate
  keyword frequency table. No network call is made here.

  ## Examples
      iex> Keywords.handler(%{title: "Elixir LiveView tutorial for beginners"}, %{name: "Agent"})
      {:ok, %{keywords: [%{keyword: "elixir", count: 1}, ...], unique: 4}}
  """

  use Lux.Prism,
    name: "YouTube Keywords",
    description:
      "Extracts and ranks keywords from a video title or a batch of titles with stopword filtering",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{type: :string, description: "A single video title"},
        titles: %{type: :array, description: "A list of video titles"},
        limit: %{type: :integer, description: "Maximum number of keywords to return (default 10)"}
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        count: %{type: :integer, description: "Number of titles analysed"},
        unique: %{type: :integer, description: "Number of distinct keywords returned"},
        keywords: %{
          type: :array,
          description: "Ranked keywords: %{keyword, count}"
        }
      },
      required: ["count", "keywords"]
    }

  alias Lux.Prisms.YouTube.DataUtil

  def handler(params, _agent) do
    limit = Map.get(params, :limit, 10)

    titles =
      cond do
        is_list(Map.get(params, :titles)) -> Map.get(params, :titles)
        is_binary(Map.get(params, :title)) -> [Map.get(params, :title)]
        true -> []
      end

    ranked =
      titles
      |> Enum.flat_map(&DataUtil.tokenize/1)
      |> Enum.reject(&stopword?/1)
      |> Enum.filter(&(String.length(&1) > 2))
      |> Enum.frequencies()
      |> DataUtil.rank_keywords(limit)
      |> Enum.map(fn
        {keyword, count} -> %{keyword: keyword, count: count}
        %{keyword: _, count: _} = m -> m
      end)

    result = %{
      count: length(titles),
      unique: length(ranked),
      keywords: ranked
    }

    {:ok, result}
  end

  # Local stopword check mirrors DataUtil's set so keyword extraction stays
  # self-contained and auditable. Kept in sync with DataUtil.@stopwords.
  @stopwords ~w(
    the a an and or but of to in on for with is are was were be been being
    this that these those it its as at by from your you we our their his her
    not no nor so if then than too very can will just about into over under
    after before more most some any each which who whom what when where why
    how all also out up down off again further once here there both few other
    such only own same now get got via vs
  )

  defp stopword?(word), do: word in @stopwords
end