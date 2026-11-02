defmodule Lux.YouTube.ContentIntelligence.MetadataGeneratorTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentIntelligence.MetadataGenerator

  describe "generate_package/1" do
    test "constructs full SEO description, chapters, hashtags, and bounded tags" do
      params = %{
        title: "How to Build Production Multi-Agent Systems in Elixir",
        niche: "AI Engineering",
        summary: "Comprehensive guide to designing, deploying, and scaling Lux agents.",
        keywords: ["elixir", "lux", "agents", "multi-agent", "otp"],
        links: ["https://lux.agent", "https://github.com/Spectral-Finance/lux"]
      }

      package = MetadataGenerator.generate_package(params)

      assert is_binary(package.description)
      assert String.contains?(package.description, "CHAPTERS:")
      assert String.contains?(package.description, "00:00")
      assert String.contains?(package.description, "RESOURCES & LINKS:")
      assert length(package.hashtags) == 3
      assert package.tags_total_characters <= 495
      assert is_binary(package.tags_comma_separated)
      assert length(package.tags_list) > 5
    end
  end

  describe "generate_tags/3" do
    test "deduplicates and strictly respects the 500-character constraint" do
      keywords = Enum.map(1..50, &"extraordinarily_long_keyword_string_number_#{&1}")
      {tags, tags_str, char_count} = MetadataGenerator.generate_tags(keywords, "test", "Sample Title")

      assert char_count <= 495
      assert String.length(tags_str) == char_count
      assert length(tags) == length(Enum.uniq_by(tags, &String.downcase/1))
    end
  end
end
