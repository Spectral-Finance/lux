defmodule Lux.Prisms.YouTube.ContentOptimizerTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.ContentOptimizer

  test "optimize good thumbnail" do
    {:ok, result} = ContentOptimizer.optimize_thumbnail(%{width: 1280, height: 720, file_size_kb: 500, has_text: true, has_face: true})
    assert result.score == 100
    assert result.optimized
  end

  test "optimize bad thumbnail" do
    {:ok, result} = ContentOptimizer.optimize_thumbnail(%{width: 640, height: 360, file_size_kb: 3000, has_text: false, has_face: false})
    assert result.score < 100
    assert length(result.issues) >= 3
  end

  test "generate end screen" do
    {:ok, es} = ContentOptimizer.generate_end_screen(%{video_duration: 600, subscribe: true, next_video: "abc", playlist: "pl1"})
    assert length(es.elements) == 3
    assert es.duration == 20
  end

  test "generate cards" do
    {:ok, cards} = ContentOptimizer.generate_cards(%{
      video_duration: 600,
      links: [%{type: :video, target: "v1", teaser: "Watch next"}, %{type: :playlist, target: "p1"}]
    })
    assert cards.count == 2
    assert hd(cards.cards).time == 200
  end

  test "optimize good metadata" do
    {:ok, result} = ContentOptimizer.optimize_metadata(%{
      title: "How to Build a REST API with Elixir and Phoenix",
      description: String.duplicate("Great content about building APIs. ", 5),
      tags: ~w(elixir phoenix api rest tutorial programming)
    })
    assert result.score >= 80
  end

  test "optimize bad metadata" do
    {:ok, result} = ContentOptimizer.optimize_metadata(%{title: "Hi", description: "Short", tags: ["a"]})
    assert result.score < 100
    assert length(result.issues) >= 2
  end
end
