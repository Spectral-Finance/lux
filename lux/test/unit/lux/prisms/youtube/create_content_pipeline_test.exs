defmodule Lux.Prisms.YouTube.CreateContentPipelineTest do
  use UnitCase, async: true

  alias Lux.Prisms.YouTube.CreateContentPipeline

  test "runs the content pipeline as a prism" do
    assert {:ok, pipeline} =
             CreateContentPipeline.run(%{
               "topic" => "video retention analytics",
               "target_audience" => "education channels",
               "goal" => "increase average view duration",
               "languages" => ["en", "fr"]
             })

    assert pipeline.script.working_title == "Video Retention Analytics for education channels"
    assert length(pipeline.localization.languages) == 2
    assert Enum.any?(pipeline.testing.experiments, &(&1.name == "title promise"))
  end

  test "returns validation errors from the pipeline" do
    assert {:error, {:missing_fields, [:goal]}} =
             CreateContentPipeline.run(%{
               "topic" => "creator workflow",
               "target_audience" => "solo creators"
             })
  end
end
