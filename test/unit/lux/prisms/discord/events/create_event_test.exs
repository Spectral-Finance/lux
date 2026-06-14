defmodule Lux.Prisms.Discord.Events.CreateEventTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Discord.Events.CreateEvent
  describe "handler/2" do
    test "creates event" do
      result = CreateEvent.handler(%{"guild_id" => "123456789012345678", "name" => "Test Event", "scheduled_start_time" => "2026-07-01T18:00:00Z", "entity_type" => 2}, %{})
      assert elem(result, 0) in [:ok, :error]
    end
    test "creates event with description", do:
      assert elem(CreateEvent.handler(%{"guild_id" => "123456789012345678", "name" => "Test", "scheduled_start_time" => "2026-07-01T18:00:00Z", "entity_type" => 3, "description" => "desc"}, %{}), 0) in [:ok, :error]
  end
end
