defmodule Lux.Prisms.YouTube.OptimizeTitle do
  @moduledoc """
  A prism that scores and improves YouTube video titles (lux issue #69 —
  "Title and thumbnail optimization").

  Pure and deterministic. Encodes common creator heuristics into a 0-100
  score: length in the 40-70 char sweet spot, presence of a power word, a
  number hook, keyword front-loading, and a sane caps ratio. `suggest` mode
  returns improved variants ranked by score.

  ## Examples
      iex> OptimizeTitle.handler(%{title: "Master Elixir: 7 Tips That Work"}, %{name: "Agent"})
      {:ok, %{title: "Master Elixir: 7 Tips That Work", score: 100.0, length: 31}}
  """

  use Lux.Prism,
    name: "Optimize YouTube Title",
    description: "Scores a YouTube title (0-100) and optionally suggests improved variants",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{type: :string, description: "The video title to score"},
        keyword: %{type: :string, description: "Optional target keyword for front-loading"},
        suggest: %{
          type: :boolean,
          description: "If true, also return ranked improved variants",
          default: false
        }
      },
      required: ["title"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        title: %{type: :string, description: "The scored title"},
        score: %{type: :number, description: "0-100 title quality score"},
        length: %{type: :integer, description: "Title length in characters"},
        components: %{type: :object, description: "Per-factor sub-scores"},
        reasons: %{type: :array, description: "Human-readable scoring reasons"},
        suggestions: %{type: :array, description: "Ranked improved variants (if suggest=true)"}
      },
      required: ["title", "score"]
    }

  alias Lux.Prisms.YouTube.Util

  @min_len 40
  @max_len 70
  @weights %{
    length: 0.30,
    power: 0.20,
    number: 0.15,
    keyword: 0.20,
    caps: 0.15
  }

  def handler(params, _agent) do
    title = Map.get(params, :title, "")
    keyword = Map.get(params, :keyword)

    if String.trim(title) == "" do
      result = %{
        title: title,
        score: 0.0,
        length: 0,
        components: %{length: 0.0, power: 0.0, number: 0.0, keyword: 0.0, caps: 0.0},
        reasons: ["empty title"]
      }

      result =
        if Map.get(params, :suggest, false) do
          Map.put(result, :suggestions, [])
        else
          result
        end

      {:ok, result}
    else
      do_score(title, keyword, params)
    end
  end

  defp do_score(title, keyword, params) do
    n = String.length(title)
    tokens = Util.tokenize(title)
    reasons = []

    # length score (peak inside [40, 70])
    {length_score, reasons} =
      cond do
        n == 0 ->
          {0.0, ["empty title" | reasons]}

        n >= @min_len and n <= @max_len ->
          {100.0, reasons}

        n < @min_len ->
          {max(0.0, n / @min_len * 100.0), ["too short" | reasons]}

        true ->
          {max(0.0, 100.0 - (n - @max_len) * 2.0), ["too long" | reasons]}
      end

    # power word
    {power_score, reasons} =
      if Util.has_power_word?(tokens) do
        {100.0, ["has power word" | reasons]}
      else
        {40.0, reasons}
      end

    # number hook
    {number_score, reasons} =
      if Regex.match?(~r/\d/, title) do
        {100.0, ["has number" | reasons]}
      else
        {50.0, reasons}
      end

    # keyword front-loading
    {keyword_score, kw_reasons} = score_keyword(title, keyword)
    reasons = reasons ++ kw_reasons

    # caps ratio
    caps_score = score_caps(title)

    components = %{
      length: round(length_score * 10) / 10,
      power: power_score,
      number: number_score,
      keyword: keyword_score,
      caps: round(caps_score * 10) / 10
    }

    total =
      components
      |> Enum.reduce(0.0, fn {k, v}, acc -> acc + v * Map.fetch!(@weights, k) end)

    result = %{
      title: title,
      score: round(total * 10) / 10,
      length: n,
      components: components,
      reasons: Enum.reverse(reasons)
    }

    result =
      if Map.get(params, :suggest, false) do
        Map.put(result, :suggestions, suggest(title, keyword))
      else
        result
      end

    {:ok, result}
  end

  defp score_keyword(title, nil), do: {50.0, []}

  defp score_keyword(title, keyword) do
    down = String.downcase(title)
    kl = String.downcase(keyword)

    cond do
      String.starts_with?(down, kl) -> {100.0, ["keyword front-loaded"]}
      String.contains?(down, kl) -> {75.0, ["keyword present"]}
      true -> {50.0, []}
    end
  end

  defp score_caps(title) do
    letters = title |> String.graphemes() |> Enum.filter(&letter?(&1))
    caps = Enum.count(letters, &uppercase_letter?(&1))

    if letters == [] do
      0.0
    else
      ratio = caps / length(letters)
      if ratio <= 0.4, do: 100.0, else: max(0.0, 100.0 - ratio * 100.0)
    end
  end

  defp letter?(<<c::utf8>>), do: (c >= ?a and c <= ?z) or (c >= ?A and c <= ?Z)
  defp letter?(_), do: false

  defp uppercase_letter?(<<c::utf8>>), do: c >= ?A and c <= ?Z
  defp uppercase_letter?(_), do: false

  defp suggest(title, keyword) do
    base = String.trim(title)
    kw = keyword || top_keyword(base)

    candidates = []

    candidates =
      if not Regex.match?(~r/\d/, base) do
        candidates ++
          ["#{base}: 7 Tips That Work", "7 #{String.capitalize(kw)} Tips You Need in 2026"]
      else
        candidates
      end

    candidates =
      if not Util.has_power_word?(base) do
        candidates ++ ["#{base} — The Ultimate Guide", "#{base}: A Proven, Simple Approach"]
      else
        candidates
      end

    candidates =
      if keyword && !String.starts_with?(String.downcase(base), String.downcase(keyword)) do
        candidates ++ ["#{String.capitalize(keyword)} — #{base}"]
      else
        candidates
      end

    candidates = Enum.uniq(candidates ++ [base])

    candidates
    |> Enum.map(&%{title: &1, score: score_title(&1, keyword)})
    |> Enum.sort_by(& &1.score, :desc)
    |> Enum.take(3)
  end

  defp score_title(title, keyword) do
    {:ok, r} = handler(%{title: title, keyword: keyword}, %{})
    r.score
  end

  defp top_keyword(title) do
    case Util.content_words(title) do
      [] -> "video"
      words -> words |> Enum.frequencies() |> Enum.max_by(fn {_w, c} -> c end) |> elem(0)
    end
  end
end
