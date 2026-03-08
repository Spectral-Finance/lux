defmodule Lux.Prisms.YouTube.Community.CommentManager do
  @moduledoc """
  Comment analysis, response generation, and management for YouTube.
  """

  use GenServer

  defstruct [:comments, :responses, :stats]

  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def analyze_comment(pid \\ __MODULE__, comment) do
    GenServer.call(pid, {:analyze, comment})
  end

  def generate_response(pid \\ __MODULE__, comment) do
    GenServer.call(pid, {:generate_response, comment})
  end

  def batch_analyze(pid \\ __MODULE__, comments) do
    GenServer.call(pid, {:batch_analyze, comments})
  end

  def get_stats(pid \\ __MODULE__) do
    GenServer.call(pid, :stats)
  end

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{comments: [], responses: [], stats: %{total: 0, positive: 0, negative: 0, neutral: 0, spam: 0}}}
  end

  @impl true
  def handle_call({:analyze, comment}, _from, state) do
    analysis = do_analyze(comment)
    stats = update_stats(state.stats, analysis)
    {:reply, {:ok, analysis}, %{state | comments: [analysis | state.comments], stats: stats}}
  end

  @impl true
  def handle_call({:generate_response, comment}, _from, state) do
    analysis = do_analyze(comment)
    response = build_response(analysis)
    {:reply, {:ok, %{comment: comment, analysis: analysis, response: response}},
     %{state | responses: [response | state.responses]}}
  end

  @impl true
  def handle_call({:batch_analyze, comments}, _from, state) do
    results = Enum.map(comments, &do_analyze/1)
    stats = Enum.reduce(results, state.stats, &update_stats(&2, &1))
    {:reply, {:ok, results}, %{state | comments: results ++ state.comments, stats: stats}}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply, {:ok, state.stats}, state}
  end

  defp do_analyze(comment) do
    text = comment[:text] || ""
    sentiment = analyze_sentiment(text)
    is_spam = is_spam?(text)
    is_question = String.contains?(text, "?")

    %{
      id: comment[:id],
      text: text,
      author: comment[:author],
      sentiment: sentiment,
      is_spam: is_spam,
      is_question: is_question,
      word_count: length(String.split(text, ~r/\s+/, trim: true)),
      has_link: Regex.match?(~r/https?:\/\//, text),
      language: detect_language(text)
    }
  end

  defp analyze_sentiment(text) do
    words = text |> String.downcase() |> String.split(~r/\W+/, trim: true)
    pos = ~w(love great awesome amazing good excellent best wonderful fantastic helpful)
    neg = ~w(hate bad terrible awful worst horrible poor ugly disappointing spam)
    p = Enum.count(words, &(&1 in pos))
    n = Enum.count(words, &(&1 in neg))
    cond do
      p > n -> :positive
      n > p -> :negative
      true -> :neutral
    end
  end

  defp is_spam?(text) do
    t = String.downcase(text)
    spam_patterns = [~r/check my channel/, ~r/sub4sub/, ~r/free \w+ at/, ~r/click here/, ~r/bit\.ly/]
    Enum.any?(spam_patterns, &Regex.match?(&1, t))
  end

  defp detect_language(text) do
    cond do
      Regex.match?(~r/[\p{Han}]/u, text) -> "zh"
      Regex.match?(~r/[\p{Hiragana}\p{Katakana}]/u, text) -> "ja"
      Regex.match?(~r/[\p{Hangul}]/u, text) -> "ko"
      true -> "en"
    end
  end

  defp build_response(analysis) do
    cond do
      analysis.is_spam -> %{action: :hide, text: nil}
      analysis.is_question -> %{action: :reply, text: "Great question! Let me look into that."}
      analysis.sentiment == :positive -> %{action: :heart, text: "Thank you so much! 🙏"}
      analysis.sentiment == :negative -> %{action: :reply, text: "Sorry to hear that. Could you share more details so we can improve?"}
      true -> %{action: :none, text: nil}
    end
  end

  defp update_stats(stats, analysis) do
    stats
    |> Map.update!(:total, &(&1 + 1))
    |> Map.update!(analysis.sentiment, &(&1 + 1))
    |> then(fn s -> if analysis.is_spam, do: Map.update!(s, :spam, &(&1 + 1)), else: s end)
  end
end
