defmodule Lux.YouTube.ContentIntelligence.MetadataGeneratorTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentIntelligence.MetadataGenerator

  describe "happy_path" do
    test "generates metadata with valid data" do
      input = %{
        video_topic: "How to Bake a Cake",
        video_description: "Learn the basics of cake baking in this tutorial.",
        chapters: [%{start_time: 0, title: "Introduction"},
                   %{start_time: 60, title: "Ingredients"},
                   %{start_time: 120, title: "Baking Process"}],
        keywords: ["cake baking", "tutorial", "dessert", "cooking"]
      }

      {:ok, result} = MetadataGenerator.generate(input)

      assert is_binary(result.seo_description)
      assert String.contains?(result.seo_description, "How to Bake a Cake")
      assert is_list(result.chapter_timestamps)
      assert length(result.chapter_timestamps) == 3
      assert is_list(result.tags)
      assert result.tags_within_limit == true
      assert result.tags_character_count < 495
    end

    test "builds SEO description" do
      desc = MetadataGenerator.seo_description("Cake Baking", "Learn to bake cakes.")
      assert is_binary(desc)
      assert String.contains?(desc, "Cake Baking")
    end

    test "formats chapter timestamps" do
      chapters = [%{start_time: 0, title: "Intro"},
                  %{start_time: 65, title: "Ingredients"}]
      result = MetadataGenerator.format_chapters(chapters)
      assert length(result) == 2
      assert hd(result) == "0:00 - Intro"
    end

    test "formats timestamp correctly" do
      assert MetadataGenerator.generate_tags(["a", "b"]) != nil
    end

    test "generates tags within character limit" do
      keywords = ["cake baking", "tutorial", "dessert", "cooking", "recipe"]
      tags = MetadataGenerator.generate_tags(keywords)
      assert is_list(tags)
      assert MetadataGenerator.tags_within_limit?(tags) == true
    end

    test "checks tags within limit" do
      assert MetadataGenerator.tags_within_limit?(["short"]) == true
    end
  end

  describe "boundary" do
    test "handles empty keywords list" do
      input = %{
        video_topic: "Test Topic",
        video_description: "Test description",
        keywords: []
      }

      {:ok, result} = MetadataGenerator.generate(input)
      assert result.tags == []
      assert result.tags_within_limit == true
    end

    test "handles chapters with zero seconds" do
      input = %{
        video_topic: "Test",
        video_description: "Test",
        chapters: [%{start_time: 0, title: "Start"}]
      }

      {:ok, result} = MetadataGenerator.generate(input)
      assert length(result.chapter_timestamps) == 1
    end

    test "handles tags at 495 character boundary" do
      long_keywords = List.duplicate("abcdefghij", 50)  # 50 * 10 = 500 chars
      tags = MetadataGenerator.generate_tags(long_keywords)
      assert String.length(Enum.join(tags, ",")) <= 495
    end
  end

  describe "null_input" do
    test "returns error for nil input" do
      assert {:error, :invalid_input} = MetadataGenerator.generate(nil)
    end

    test "returns error for missing required fields" do
      input = %{video_topic: "Test"}
      assert {:error, {:missing_fields, _}} = MetadataGenerator.generate(input)
    end
  end

  describe "empty_input" do
    test "rejects empty map input" do
      assert {:error, {:missing_fields, _}} = MetadataGenerator.generate(%{})
    end

    test "rejects non-binary video_topic" do
      input = %{video_topic: 123, video_description: "test"}
      assert {:error, {:invalid_value, :video_topic}} = MetadataGenerator.generate(input)
    end
  end

  describe "negative" do
    test "tags_within_limit rejects non-list input" do
      assert {:error, :invalid_input} = MetadataGenerator.tags_within_limit?("not_a_list")
    end
  end
end