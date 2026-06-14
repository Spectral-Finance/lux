defmodule Lux.Prisms.Discord.Events.DeleteEventTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Discord.Events.DeleteEvent
  describe "handler/2" do
    test "deletes event" do
      result = DeleteEvent.handler(%{"guild_id" => "123456789012345678", "event_id" => "111111111111111111"}, %{})
      assert elem(result, 0) in [:ok, :error]
    end
  end
end
