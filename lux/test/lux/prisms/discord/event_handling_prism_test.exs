defmodule Lux.Prisms.Discord.EventHandlingPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Discord.EventHandlingPrism

  describe "handler/2" do
    test "returns error for missing guild_id for schedule_event" do
      input = %{
        "action" => "schedule_event",
        "name" => "My Event",
        "start_time" => "2023-10-01T10:00:00Z"
      }
      assert {:error, "guild_id, name, and start_time are required for schedule_event"} = EventHandlingPrism.handler(input, nil)
    end
    
    test "returns error for missing start_time for schedule_event" do
      input = %{
        "action" => "schedule_event",
        "guild_id" => "123",
        "name" => "My Event"
      }
      assert {:error, "guild_id, name, and start_time are required for schedule_event"} = EventHandlingPrism.handler(input, nil)
    end
  end
end
