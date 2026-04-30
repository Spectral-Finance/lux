defmodule Lux.Prisms.Youtube.ScriptGeneratorPrismTest do
  use ExUnit.Case, async: true
  doctest Lux.Prisms.Youtube.ScriptGeneratorPrism

  describe "run/1" do
    test "generates script with required fields" do
      assert {:ok, result} = Lux.Prisms.Youtube.ScriptGeneratorPrism.run(%{
        topic: "Building a DeFi Dashboard",
        target_audience: "Web3 developers",
        duration_minutes: 10
      })

      assert result[:script] != nil
      assert result[:sections] != nil
      assert result[:estimated_duration] == 600
      assert result[:word_count] == 1500
      assert result[:hooks] != nil
      assert result[:suggested_ctas] != nil
    end

    test "generates correct number of sections" do
      {:ok, result} = Lux.Prisms.Youtube.ScriptGeneratorPrism.run(%{
        topic: "Test Topic",
        duration_minutes: 10,
        include_hooks: true,
        include_cta: true
      })

      sections = result[:sections]
      assert length(sections) >= 4  # Hook, Intro, Content, Summary, CTA
    end

    test "respects duration_minutes parameter" do
      {:ok, result} = Lux.Prisms.Youtube.ScriptGeneratorPrism.run(%{
        topic: "Test",
        duration_minutes: 5
      })

      assert result[:estimated_duration] == 300
      assert result[:word_count] == 750
    end

    test "generates hooks when include_hooks is true" do
      {:ok, result} = Lux.Prisms.Youtube.ScriptGeneratorPrism.run(%{
        topic: "Test Topic",
        include_hooks: true
      })

      assert length(result[:hooks]) > 0
    end

    test "generates empty hooks when include_hooks is false" do
      {:ok, result} = Lux.Prisms.Youtube.ScriptGeneratorPrism.run(%{
        topic: "Test Topic",
        include_hooks: false
      })

      assert result[:hooks] == []
    end

    test "generates CTAs when include_cta is true" do
      {:ok, result} = Lux.Prisms.Youtube.ScriptGeneratorPrism.run(%{
        topic: "Test Topic",
        include_cta: true
      })

      assert length(result[:suggested_ctas]) > 0
    end

    test "generates empty CTAs when include_cta is false" do
      {:ok, result} = Lux.Prisms.Youtube.ScriptGeneratorPrism.run(%{
        topic: "Test Topic",
        include_cta: false
      })

      assert result[:suggested_ctas] == []
    end

    test "uses key_points for section generation" do
      {:ok, result} = Lux.Prisms.Youtube.ScriptGeneratorPrism.run(%{
        topic: "Test Topic",
        key_points: ["Point A", "Point B", "Point C"]
      })

      sections = result[:sections]
      assert Enum.any?(sections, &(&1[:name] || &1["name"] || "") |> String.contains?("Point"))
    end

    test "has correct prism metadata" do
      assert Lux.Prisms.Youtube.ScriptGeneratorPrism.__meta__(:name) == "YouTube Script Generator"
    end

    test "input schema has required fields" do
      schema = Lux.Prisms.Youtube.ScriptGeneratorPrism.__input_schema__()
      assert "topic" in schema[:required]
    end
  end
end
