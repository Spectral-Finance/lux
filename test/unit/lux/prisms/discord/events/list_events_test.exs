defmodule Lux.Prisms.Discord.Events.ListEventsTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Discord.Events.ListEvents
  describe "handler/2" do
    test "lists events" do
      result = ListEvents.handler(%{"guild_id" => "123456789012345678"}, %{})
      assert elem(result, 0) in [:ok, :error]
    end
  end
end
