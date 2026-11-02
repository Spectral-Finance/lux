defmodule Lux.Prisms.YouTubeContentIntelligencePrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.YouTubeContentIntelligencePrism

  describe "handler/2" do
    test "executes optimize_title action" do
      {:ok, response} =
        YouTubeContentIntelligencePrism.run(%{
          action: "optimize_title",
          payload: %{title: "Ultimate Guide to AI Agents [2026]"}
        })

      assert response.action == "optimize_title"
      assert response.result.ctr_potential_score >= 70.0
      assert response.result.has_brackets == true
    end

    test "executes generate_title_variants action" do
      {:ok, response} =
        YouTubeContentIntelligencePrism.run(%{
          action: "generate_title_variants",
          payload: %{topic: "Distributed Systems"}
        })

      assert response.action == "generate_title_variants"
      assert length(response.result.variants) == 4
    end

    test "executes predict_posting_time action" do
      {:ok, response} =
        YouTubeContentIntelligencePrism.run(%{
          action: "predict_posting_time",
          payload: %{timezone: "America/New_York"}
        })

      assert response.action == "predict_posting_time"
      assert response.result.recommended_day_of_week == :thursday
      assert response.result.recommended_utc_hour == 19
    end

    test "executes generate_metadata action" do
      {:ok, response} =
        YouTubeContentIntelligencePrism.run(%{
          action: "generate_metadata",
          payload: %{
            title: "Scaling Elixir with Lux",
            niche: "Software Engineering",
            summary: "Learn how to build resilient systems.",
            keywords: ["elixir", "lux"]
          }
        })

      assert response.action == "generate_metadata"
      assert is_binary(response.result.description)
      assert response.result.tags_total_characters <= 495
    end

    test "executes analyze_trends action" do
      {:ok, response} =
        YouTubeContentIntelligencePrism.run(%{
          action: "analyze_trends",
          payload: %{niche: "ai"}
        })

      assert response.action == "analyze_trends"
      assert length(response.result.trends) > 0
    end

    test "handles unknown action gracefully" do
      {:error, reason} =
        YouTubeContentIntelligencePrism.run(%{
          action: "invalid_action",
          payload: %{}
        })

      assert String.contains?(reason, "Unknown action: invalid_action")
    end
  end

  describe "schema validation" do
    test "validates prism definition and schema" do
      prism = YouTubeContentIntelligencePrism.view()
      assert prism.name == "YouTube Content Intelligence Prism"
      assert prism.input_schema.required == ["action"]
      assert Map.has_key?(prism.input_schema.properties, :action)
      assert Map.has_key?(prism.input_schema.properties, :payload)
      assert prism.output_schema.required == ["action", "result"]
    end
  end
end
