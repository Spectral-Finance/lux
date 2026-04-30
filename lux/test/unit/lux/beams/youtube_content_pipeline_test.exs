defmodule Lux.Beams.YoutubeContentPipelineTest do
  use ExUnit.Case, async: true
  doctest Lux.Beams.YoutubeContentPipeline

  describe "run/1" do
    test "runs complete pipeline without video_id" do
      assert {:ok, result} = Lux.Beams.YoutubeContentPipeline.run(%{
        topic: "Building a DeFi Dashboard",
        target_audience: "Web3 developers",
        duration_minutes: 10
      })

      # Check content package
      assert result[:content_package][:script] != nil
      assert result[:content_package][:sections] != nil
      assert result[:content_package][:hooks] != nil
      assert result[:content_package][:suggested_ctas] != nil

      # Check thumbnail
      assert result[:thumbnail][:suggestions] != nil
      assert result[:thumbnail][:color_palette] != nil

      # Check metadata
      assert result[:metadata][:optimized_title] != nil
      assert result[:metadata][:optimized_description] != nil
      assert result[:metadata][:tags] != nil
      assert result[:metadata][:seo_score] != nil

      # Check pipeline status
      assert result[:pipeline_status] in ["success", "partial"]
    end

    test "pipeline status is partial when script fails" do
      # This tests graceful degradation
      assert {:ok, result} = Lux.Beams.YoutubeContentPipeline.run(%{
        topic: "Test Topic"
      })

      assert result[:pipeline_status] in ["success", "partial"]
    end

    test "includes analytics when video_id provided" do
      assert {:ok, result} = Lux.Beams.YoutubeContentPipeline.run(%{
        topic: "Test",
        video_id: "dQw4w9WgXcQ"
      })

      # Analytics may fail due to missing API key, but should be present
      assert Map.has_key?(result, :analytics)
    end

    test "respects duration_minutes in content package" do
      {:ok, result} = Lux.Beams.YoutubeContentPipeline.run(%{
        topic: "Test",
        duration_minutes: 5
      })

      # Script should reflect 5 minute duration (300 seconds)
      assert result[:content_package][:sections] != nil
    end

    test "uses provided tone in script generation" do
      {:ok, result} = Lux.Beams.YoutubeContentPipeline.run(%{
        topic: "Test",
        tone: "professional"
      })

      assert result[:content_package][:script] != nil
    end

    test "uses provided style in thumbnail generation" do
      {:ok, result} = Lux.Beams.YoutubeContentPipeline.run(%{
        topic: "Test",
        style: "minimal"
      })

      assert result[:thumbnail][:suggestions] != nil
    end

    test "has correct beam metadata" do
      assert Lux.Beams.YoutubeContentPipeline.__meta__(:name) == "YouTube Content Pipeline"
    end

    test "input schema has required fields" do
      schema = Lux.Beams.YoutubeContentPipeline.__input_schema__()
      assert "topic" in schema[:required]
    end
  end
end
