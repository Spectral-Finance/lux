defmodule Lux.Prisms.YouTube.GenerateVideoScriptTest do
  @moduledoc """
  Test suite for the GenerateVideoScript prism.
  These tests verify the prism's ability to:
  - Generate structured video scripts for different styles
  - Apply appropriate hooks and CTAs per style
  - Handle short and long video durations
  - Generate correct thumbnail text suggestions
  - Support multi-language output metadata
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.YouTube.GenerateVideoScript

  @agent_ctx %{agent: %{name: "TestAgent"}}

  describe "handler/2" do
    test "generates educational script with default duration" do
      assert {:ok, result} =
               GenerateVideoScript.handler(
                 %{"topic" => "machine learning basics", "style" => "educational"},
                 @agent_ctx
               )

      assert is_binary(result.hook)
      assert String.contains?(result.hook, "machine learning basics")
      assert is_list(result.sections)
      assert length(result.sections) > 0
      assert is_binary(result.call_to_action)
      assert String.contains?(result.call_to_action, "subscribe")
      assert result.estimated_word_count == 1500
      assert result.style == "educational"
      assert result.language == "en"
    end

    test "generates tutorial script with custom duration" do
      assert {:ok, result} =
               GenerateVideoScript.handler(
                 %{
                   "topic" => "build a REST API",
                   "style" => "tutorial",
                   "target_duration_minutes" => 20
                 },
                 @agent_ctx
               )

      assert String.contains?(result.hook, "build a REST API")
      assert result.estimated_word_count == 3000
      assert result.style == "tutorial"

      # Should include FAQ section for 20-minute videos
      titles = Enum.map(result.sections, & &1.title)
      assert Enum.any?(titles, &String.contains?(&1, "Q&A"))
    end

    test "generates vlog script style" do
      assert {:ok, result} =
               GenerateVideoScript.handler(
                 %{"topic" => "Tokyo street food tour", "style" => "vlog"},
                 @agent_ctx
               )

      assert String.contains?(result.hook, "Tokyo street food tour")
      assert result.style == "vlog"
      assert is_binary(result.call_to_action)
    end

    test "generates thumbnail text suggestion for short topics" do
      assert {:ok, result} =
               GenerateVideoScript.handler(%{"topic" => "Python"}, @agent_ctx)

      assert result.thumbnail_text_suggestion == "PYTHON"
    end

    test "truncates thumbnail text suggestion to 3 words for long topics" do
      assert {:ok, result} =
               GenerateVideoScript.handler(
                 %{"topic" => "advanced elixir concurrency patterns and techniques"},
                 @agent_ctx
               )

      assert result.thumbnail_text_suggestion == "ADVANCED ELIXIR CONCURRENCY"
    end

    test "supports multi-language metadata" do
      assert {:ok, result} =
               GenerateVideoScript.handler(
                 %{"topic" => "cocina española", "language" => "es", "style" => "educational"},
                 @agent_ctx
               )

      assert result.language == "es"
    end

    test "sections include estimated word counts" do
      assert {:ok, result} =
               GenerateVideoScript.handler(
                 %{"topic" => "blockchain", "target_duration_minutes" => 10},
                 @agent_ctx
               )

      Enum.each(result.sections, fn section ->
        assert Map.has_key?(section, :estimated_words)
        assert is_integer(section.estimated_words)
        assert section.estimated_words > 0
      end)
    end

    test "short video does not include FAQ section" do
      assert {:ok, result} =
               GenerateVideoScript.handler(
                 %{"topic" => "quick tip", "target_duration_minutes" => 5},
                 @agent_ctx
               )

      titles = Enum.map(result.sections, & &1.title)
      refute Enum.any?(titles, &String.contains?(&1, "Q&A"))
    end
  end
end
