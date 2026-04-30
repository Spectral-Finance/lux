defmodule Lux.Prisms.Youtube.ThumbnailSuggestionPrismTest do
  use ExUnit.Case, async: true
  doctest Lux.Prisms.Youtube.ThumbnailSuggestionPrism

  describe "run/1" do
    test "generates thumbnail suggestions" do
      assert {:ok, result} = Lux.Prisms.Youtube.ThumbnailSuggestionPrism.run(%{
        video_title: "Building a DeFi Dashboard in 10 Minutes",
        category: "Technology",
        niche: "Web3 development"
      })

      assert result[:suggestions] != nil
      assert length(result[:suggestions]) >= 3
      assert result[:color_palette] != nil
      assert result[:recommended_dimensions] == "1280x720 (16:9 ratio)"
      assert result[:best_practices] != nil
    end

    test "each suggestion has required fields" do
      {:ok, result} = Lux.Prisms.Youtube.ThumbnailSuggestionPrism.run(%{
        video_title: "Test Title"
      })

      Enum.each(result[:suggestions], fn suggestion ->
        assert suggestion[:name] != nil
        assert suggestion[:description] != nil
        assert suggestion[:composition] != nil
        assert suggestion[:text_overlay] != nil
        assert suggestion[:color_scheme] != nil
      end)
    end

    test "generates different palettes for different styles" do
      {:ok, bold_result} = Lux.Prisms.Youtube.ThumbnailSuggestionPrism.run(%{
        video_title: "Test",
        style: "bold"
      })

      {:ok, minimal_result} = Lux.Prisms.Youtube.ThumbnailSuggestionPrism.run(%{
        video_title: "Test",
        style: "minimal"
      })

      assert bold_result[:color_palette] != minimal_result[:color_palette]
    end

    test "has correct prism metadata" do
      assert Lux.Prisms.Youtube.ThumbnailSuggestionPrism.__meta__(:name) == "YouTube Thumbnail Suggestion"
    end

    test "input schema has required fields" do
      schema = Lux.Prisms.Youtube.ThumbnailSuggestionPrism.__input_schema__()
      assert "video_title" in schema[:required]
    end
  end
end
