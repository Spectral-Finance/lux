defmodule Lux.Prisms.Youtube.MetadataOptimizerPrismTest do
  use ExUnit.Case, async: true
  doctest Lux.Prisms.Youtube.MetadataOptimizerPrism

  describe "run/1" do
    test "generates optimized metadata" do
      assert {:ok, result} = Lux.Prisms.Youtube.MetadataOptimizerPrism.run(%{
        topic: "DeFi Dashboard Tutorial",
        target_keywords: ["defi", "dashboard", "tutorial"]
      })

      assert result[:optimized_title] != nil
      assert result[:title_alternatives] != nil
      assert result[:optimized_description] != nil
      assert result[:tags] != nil
      assert result[:seo_score] != nil
      assert result[:recommendations] != nil
    end

    test "title is within length limit" do
      {:ok, result} = Lux.Prisms.Youtube.MetadataOptimizerPrism.run(%{
        topic: "Test Topic",
        target_keywords: ["test"]
      })

      assert String.length(result[:optimized_title]) <= 60
    end

    test "generates relevant tags" do
      {:ok, result} = Lux.Prisms.Youtube.MetadataOptimizerPrism.run(%{
        topic: "DeFi Dashboard",
        target_keywords: ["defi", "dashboard"]
      })

      tags = result[:tags]
      assert Enum.any?(tags, &(&1 == "DeFi Dashboard"))
      assert Enum.any?(tags, &(&1 == "defi"))
      assert Enum.any?(tags, &(&1 == "dashboard"))
    end

    test "description includes timestamps when enabled" do
      {:ok, result} = Lux.Prisms.Youtube.MetadataOptimizerPrism.run(%{
        topic: "Test",
        include_timestamps: true
      })

      assert String.contains?(result[:optimized_description], "0:00")
      assert String.contains?(result[:optimized_description], "Chapters")
    end

    test "description excludes timestamps when disabled" do
      {:ok, result} = Lux.Prisms.Youtube.MetadataOptimizerPrism.run(%{
        topic: "Test",
        include_timestamps: false
      })

      refute String.contains?(result[:optimized_description], "0:00")
    end

    test "SEO score is between 0 and 1" do
      {:ok, result} = Lux.Prisms.Youtube.MetadataOptimizerPrism.run(%{
        topic: "Test Topic",
        target_keywords: ["test"]
      })

      assert result[:seo_score] >= 0.0
      assert result[:seo_score] <= 1.0
    end

    test "enhances existing title with keywords" do
      {:ok, result} = Lux.Prisms.Youtube.MetadataOptimizerPrism.run(%{
        topic: "Test",
        existing_title: "My Great Video About Something",
        target_keywords: ["elixir"]
      })

      assert String.contains?(result[:optimized_title], "elixir") ||
             String.contains?(String.downcase(result[:optimized_title]), "elixir")
    end

    test "has correct prism metadata" do
      assert Lux.Prisms.Youtube.MetadataOptimizerPrism.__meta__(:name) == "YouTube Metadata Optimizer"
    end

    test "input schema has required fields" do
      schema = Lux.Prisms.Youtube.MetadataOptimizerPrism.__input_schema__()
      assert "topic" in schema[:required]
    end
  end
end
