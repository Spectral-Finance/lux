defmodule Lux.Prisms.YouTube.Live.ManageBroadcastTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.YouTube.Live.ManageBroadcast

  @agent %{name: "YouTubeOps"}

  describe "handler/2" do
    test "returns a dry-run workflow plan" do
      assert {:ok, result} =
               ManageBroadcast.handler(
                 %{
                   title: "Lux live",
                   scheduled_start_time: "2026-06-06T12:00:00Z",
                   broadcast_id: "broadcast-1",
                   stream_id: "stream-1",
                   target_life_cycle_status: "testing"
                 },
                 @agent
               )

      assert result.planned == true
      assert result.mode == "dry_run"
      assert result.workflow.transition.allowed == true
      assert result.execution_boundary.live_side_effects == false
    end

    test "returns validation errors from the planner" do
      assert {:error, "Missing required YouTube live parameter scheduled_start_time"} =
               ManageBroadcast.handler(%{title: "Lux live"}, @agent)
    end
  end

  describe "schema validation" do
    test "exposes required input and output fields" do
      prism = ManageBroadcast.view()

      assert prism.input_schema.required == ["title", "scheduled_start_time"]
      assert Map.has_key?(prism.input_schema.properties, :broadcast_id)
      assert Map.has_key?(prism.input_schema.properties, :stream_id)
      assert Map.has_key?(prism.output_schema.properties, :workflow)
    end
  end
end
