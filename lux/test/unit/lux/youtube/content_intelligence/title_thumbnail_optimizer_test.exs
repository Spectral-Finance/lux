defmodule Lux.YouTube.ContentIntelligence.TitleThumbnailOptimizerTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentIntelligence.TitleThumbnailOptimizer

  describe "analyze_title/1" do
    test "correctly scores high-converting title with power words and brackets" do
      title = "The Ultimate Multi-Agent Architecture Guide [2026]"
      analysis = TitleThumbnailOptimizer.analyze_title(title)

      assert analysis.has_power_words == true
      assert "ultimate" in analysis.power_words_found
      assert analysis.has_brackets == true
      assert analysis.mobile_truncation_risk == false
      assert analysis.ctr_potential_score >= 80.0
      assert length(analysis.strengths) > 0
    end

    test "flags long titles for mobile truncation risk" do
      long_title = "This is an extremely long YouTube title that definitely exceeds sixty five characters and will truncate on smartphones"
      analysis = TitleThumbnailOptimizer.analyze_title(long_title)

      assert analysis.mobile_truncation_risk == true
      assert Enum.any?(analysis.weaknesses, &String.contains?(&1, "mobile"))
    end
  end

  describe "generate_variants/1" do
    test "produces 4 distinct psychological angle variants" do
      variants = TitleThumbnailOptimizer.generate_variants("Autonomous AI Agents")

      assert length(variants) == 4
      angles = Enum.map(variants, & &1.angle)
      assert Enum.any?(angles, &String.contains?(&1, "Authority"))
      assert Enum.any?(angles, &String.contains?(&1, "Curiosity"))
    end
  end

  describe "audit_thumbnail/1" do
    test "audits thumbnail clarity, word count, and mobile readability" do
      params = %{
        overlay_text_word_count: 3,
        has_human_face: true,
        contrast_ratio: 5.2
      }

      audit = TitleThumbnailOptimizer.audit_thumbnail(params)

      assert audit.mobile_readability_score >= 90.0
      assert audit.visual_clutter_verdict == :clean
    end
  end
end
