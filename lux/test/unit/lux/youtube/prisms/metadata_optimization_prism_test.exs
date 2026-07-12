defmodule Lux.YouTube.Prisms.MetadataOptimizationPrismTest do
  use ExUnit.Case, async: true

  alias Lux.YouTube.Prisms.MetadataOptimizationPrism

  test "generates optimized metadata and posting times" do
    input = %{
      "topic" => "Elixir Tutorial",
      "target_audience" => "developers"
    }

    assert {:ok, result} = MetadataOptimizationPrism.run(input)
    assert length(result.optimized_titles) == 3
    assert Enum.any?(result.optimized_titles, &String.contains?(&1, "Elixir Tutorial"))
    assert length(result.suggested_tags) > 0
    assert Enum.member?(result.suggested_tags, "developers")
    assert length(result.optimal_posting_times) == 3
  end
end
