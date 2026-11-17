defmodule Lux.Beams.Discord.EventHandlingBeamTest do
  @moduledoc """
  Test suite for the EventHandlingBeam module.
  """

  use UnitCase, async: true
  alias Lux.Beams.Discord.EventHandlingBeam

  describe "schema validation" do
    test "has correct input schema" do
      beam = EventHandlingBeam.view()
      assert beam.name == "Discord Event Handling"
      assert beam.input_schema.required == ["guild_id", "name", "scheduled_start_time", "privacy_level", "entity_type"]
      assert Map.has_key?(beam.input_schema.properties, :guild_id)
      assert Map.has_key?(beam.input_schema.properties, :name)
      assert Map.has_key?(beam.input_schema.properties, :entity_type)
    end

    test "has correct output schema" do
      beam = EventHandlingBeam.view()
      assert beam.output_schema.required == ["event_id", "name", "guild_id"]
    end
  end
end
