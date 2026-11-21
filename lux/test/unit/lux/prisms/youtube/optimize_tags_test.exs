defmodule Lux.Prisms.YouTube.OptimizeTagsTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.OptimizeTags

  test "extracts and packs tags within budget" do
    text = "Elixir LiveView tutorial for beginners: build real-time apps with Phoenix"
    assert {:ok, r} = OptimizeTags.handler(%{text: text, keyword: "elixir"}, %{name: "Agent"})
    assert is_list(r.tags)
    assert length(r.tags) >= 1
    assert r.tag_string == Enum.join(r.tags, ", ")
    assert r.count == length(r.tags)
    assert r.char_count <= 500
    # keyword should be present and ranked first (boosted)
    assert List.first(r.tags) == "elixir"
  end

  test "respects max_tags" do
    text = "one two three four five six seven eight nine ten eleven twelve"
    assert {:ok, r} = OptimizeTags.handler(%{text: text, max_tags: 3}, %{})
    assert length(r.tags) <= 3
  end

  test "empty text yields empty tags" do
    assert {:ok, r} = OptimizeTags.handler(%{text: ""}, %{})
    assert r.tags == []
    assert r.tag_string == ""
    assert r.count == 0
  end

  test "char budget never exceeded" do
    text = "supercalifragilistic " |> String.duplicate(20)
    assert {:ok, r} = OptimizeTags.handler(%{text: text}, %{})
    assert r.char_count <= 500
  end
end