defmodule Lux.Beams.Discord.ModerationBeamTest do
  @moduledoc """
  Test suite for the ModerationBeam module.
  """

  use UnitCase, async: true
  alias Lux.Beams.Discord.ModerationBeam

  describe "schema validation" do
    test "has correct input schema" do
      beam = ModerationBeam.view()
      assert beam.name == "Discord Moderation"
      assert beam.input_schema.required == ["guild_id", "user_id"]
      assert Map.has_key?(beam.input_schema.properties, :guild_id)
      assert Map.has_key?(beam.input_schema.properties, :user_id)
      assert Map.has_key?(beam.input_schema.properties, :delete_message_seconds)
      assert Map.has_key?(beam.input_schema.properties, :reason)
    end

    test "has correct output schema" do
      beam = ModerationBeam.view()
      assert beam.output_schema.required == ["banned", "user_id", "guild_id"]
    end
  end
end
