defmodule Lux.Beams.Discord.MessageManagementBeamTest do
  @moduledoc """
  Test suite for the MessageManagementBeam module.
  """

  use UnitCase, async: true
  alias Lux.Beams.Discord.MessageManagementBeam

  describe "schema validation" do
    test "has correct input schema" do
      beam = MessageManagementBeam.view()
      assert beam.name == "Discord Message Management"
      assert beam.input_schema.required == ["channel_id", "content"]
      assert Map.has_key?(beam.input_schema.properties, :channel_id)
      assert Map.has_key?(beam.input_schema.properties, :content)
    end

    test "has correct output schema" do
      beam = MessageManagementBeam.view()
      assert beam.output_schema.required == ["message_id", "channel_id", "content"]
      assert Map.has_key?(beam.output_schema.properties, :message_id)
      assert Map.has_key?(beam.output_schema.properties, :pinned)
    end
  end
end
