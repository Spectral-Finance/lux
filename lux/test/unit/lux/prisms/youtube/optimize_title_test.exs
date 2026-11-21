defmodule Lux.Prisms.YouTube.OptimizeTitleTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.OptimizeTitle

  test "scores a strong title highly" do
    title = "Master Elixir LiveView: 7 Proven Tips That Work"
    assert {:ok, r} = OptimizeTitle.handler(%{title: title}, %{name: "Agent"})
    assert r.title == title
    assert r.length == String.length(title)
    assert r.score >= 70.0
    assert "has power word" in r.reasons
    assert "has number" in r.reasons
  end

  test "empty title scores 0" do
    assert {:ok, r} = OptimizeTitle.handler(%{title: ""}, %{})
    assert r.score == 0.0
    assert "empty title" in r.reasons
  end

  test "keyword front-loading boosts score" do
    {:ok, front} =
      OptimizeTitle.handler(%{title: "Elixir tips for beginners in 2026", keyword: "elixir"}, %{})

    {:ok, mid} =
      OptimizeTitle.handler(
        %{title: "Learn about elixir and more stuff here", keyword: "elixir"},
        %{}
      )

    assert front.components.keyword == 100.0
    assert mid.components.keyword == 75.0
    assert front.score > mid.score
  end

  test "suggest mode returns ranked variants" do
    assert {:ok, r} = OptimizeTitle.handler(%{title: "elixir basics", suggest: true}, %{})
    assert is_list(r.suggestions)
    assert length(r.suggestions) >= 1
    # suggestions sorted descending by score
    scores = Enum.map(r.suggestions, & &1.score)
    assert scores == Enum.sort(scores, :desc)
  end
end
