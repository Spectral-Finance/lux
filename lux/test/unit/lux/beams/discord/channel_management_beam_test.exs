defmodule Lux.Beams.Discord.ChannelManagementBeamTest do
  @moduledoc """
  Test suite for the ChannelManagementBeam module.
  """

  use UnitCase, async: true
  alias Lux.Beams.Discord.ChannelManagementBeam

  describe "schema validation" do
    test "has correct input schema" do
      beam = ChannelManagementBeam.view()
      assert beam.name == "Discord Channel Management"
      assert beam.input_schema.required == ["guild_id", "name", "type", "overwrite_id", "overwrite_type"]
      assert Map.has_key?(beam.input_schema.properties, :guild_id)
      assert Map.has_key?(beam.input_schema.properties, :name)
    end

    test "has correct output schema" do
      beam = ChannelManagementBeam.view()
      assert beam.output_schema.required == ["channel_id", "name", "guild_id"]
      assert Map.has_key?(beam.output_schema.properties, :permissions_set)
    end
  end
end
