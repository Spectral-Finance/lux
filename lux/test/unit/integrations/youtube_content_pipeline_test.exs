defmodule Lux.Integrations.YouTube.ContentPipelineTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.YouTube.ContentPipeline

  test "processes valid payload and computes efficiency score" do
    assert {:error, :empty_params} = YouTube.ContentPipeline.process(%{})
    assert {:ok, %{verified: true, issue: 71}} = YouTube.ContentPipeline.process(%{active: true})
    assert {:ok, 95.0} = YouTube.ContentPipeline.compute_efficiency_score(100, 100, 500)
  end
end
