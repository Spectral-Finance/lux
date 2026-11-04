defmodule Lux.YouTube.ContentIntelligence.TitleThumbnailOptimizerTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentIntelligence.TitleThumbnailOptimizer

  describe "happy_path" do
    test "optimizes title with valid data" do
      input = %{
        title: "10 Secret Cooking Tips That Will Change Your Life",
        target_audience: "home cooks",
        include_ab_variants: true
      }

      {:ok, result} = TitleThumbnailOptimizer.optimize_title(input)

      assert result.ctr_score >= 0
      assert result.ctr_score <= 100
      assert is_list(result.ab_test_variants)
      assert length(result.ab_test_variants) == 4
      assert is_binary(result.optimized_title)
    end

    test "calculates CTR score" do
      score = TitleThumbnailOptimizer.ctr_score("10 Secret Cooking Tips")
      assert score >= 0
      assert score <= 100
    end

    test "detects mobile truncation for long titles" do
      long_title = String.duplicate("x", 100)
      assert TitleThumbnailOptimizer.mobile_truncation?(long_title) == true
    end

    test "detects no truncation for short titles" do
      assert TitleThumbnailOptimizer.mobile_truncation?("Short title") == false
    end

    test "generates A/B test variants" do
      variants = TitleThumbnailOptimizer.ab_test_variants("My Video Title")
      assert length(variants) == 4
      assert hd(variants)["variant"] == "A"
    end

    test "audits thumbnail" do
      {:ok, result} = TitleThumbnailOptimizer.audit_thumbnail("high contrast bright thumbnail")
      assert result.contrast_score >= 0
      assert result.clutter_score >= 0
      assert is_binary(result.recommendation)
    end
  end

  describe "boundary" do
    test "handles empty title" do
      input = %{title: ""}
      {:ok, result} = TitleThumbnailOptimizer.optimize_title(input)
      assert result.character_count == 0
      assert result.ctr_score <= 100
    end

    test "handles very long title" do
      long_title = String.duplicate("x", 200)
      input = %{title: long_title}
      {:ok, result} = TitleThumbnailOptimizer.optimize_title(input)
      assert result.mobile_truncation_warning != nil
    end
  end

  describe "null_input" do
    test "returns error for nil input" do
      assert {:error, :invalid_input} = TitleThumbnailOptimizer.optimize_title(nil)
    end

    test "returns error for missing title" do
      input = %{target_audience: "cooks"}
      assert {:error, {:missing_fields, _}} = TitleThumbnailOptimizer.optimize_title(input)
    end
  end

  describe "empty_input" do
    test "rejects empty map input" do
      assert {:error, {:missing_fields, _}} = TitleThumbnailOptimizer.optimize_title(%{})
    end

    test "rejects non-binary title" do
      input = %{title: 123}
      assert {:error, {:invalid_value, :title}} = TitleThumbnailOptimizer.optimize_title(input)
    end
  end

  describe "negative" do
    test "audit_thumbnail rejects non-binary input" do
      assert {:error, :invalid_input} = TitleThumbnailOptimizer.audit_thumbnail(nil)
    end
  end
end