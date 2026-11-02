defmodule Lux.Prisms.YouTubeContentCreationPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.YouTubeContentCreationPrism

  describe "handler/2" do
    test "executes generate_script action" do
      {:ok, response} =
        YouTubeContentCreationPrism.run(%{
          action: "generate_script",
          payload: %{topic: "Autonomous Distributed Agents"}
        })

      assert response.action == "generate_script"
      assert is_binary(response.result.hook)
      assert is_binary(response.result.cta)
    end

    test "executes advise_editing action" do
      sections = [
        %{name: "Hook & Stake", timestamp_estimate: "00:00"},
        %{name: "Live Implementation", timestamp_estimate: "03:00"}
      ]

      {:ok, response} =
        YouTubeContentCreationPrism.run(%{
          action: "advise_editing",
          payload: %{sections: sections}
        })

      assert response.action == "advise_editing"
      assert response.result.total_cues > 0
    end

    test "executes optimize_visuals action" do
      {:ok, response} =
        YouTubeContentCreationPrism.run(%{
          action: "optimize_visuals",
          payload: %{topic: "Elixir OTP", duration_seconds: 600}
        })

      assert response.action == "optimize_visuals"
      assert is_map(response.result.thumbnail)
      assert length(response.result.end_screens) == 3
    end

    test "executes curate_playlist action" do
      videos = ["Intro to Lux", "Scaling Agents"]

      {:ok, response} =
        YouTubeContentCreationPrism.run(%{
          action: "curate_playlist",
          payload: %{series_name: "Lux Series", videos: videos}
        })

      assert response.action == "curate_playlist"
      assert length(response.result.ordered_videos) == 2
    end

    test "executes repurpose_content action" do
      {:ok, response} =
        YouTubeContentCreationPrism.run(%{
          action: "repurpose_content",
          payload: %{topic: "High-Scale AI Systems"}
        })

      assert response.action == "repurpose_content"
      assert length(response.result.shorts_scripts) == 3
    end

    test "executes build_pipeline action" do
      {:ok, response} =
        YouTubeContentCreationPrism.run(%{
          action: "build_pipeline",
          payload: %{topic: "End-to-End Autonomous Workflows"}
        })

      assert response.action == "build_pipeline"
      assert response.result.status == :production_ready
      assert is_map(response.result.script)
    end

    test "handles unsupported action with error" do
      {:error, reason} =
        YouTubeContentCreationPrism.run(%{
          action: "unsupported_action",
          payload: %{}
        })

      assert String.contains?(reason, "Unknown action: unsupported_action")
    end
  end

  describe "schema validation" do
    test "validates prism definition and schema" do
      prism = YouTubeContentCreationPrism.view()
      assert prism.name == "YouTube Content Creation Prism"
      assert prism.input_schema.required == ["action"]
      assert Map.has_key?(prism.input_schema.properties, :action)
      assert Map.has_key?(prism.input_schema.properties, :payload)
      assert prism.output_schema.required == ["action", "result"]
    end
  end
end
