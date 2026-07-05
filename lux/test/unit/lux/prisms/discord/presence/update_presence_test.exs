defmodule Lux.Prisms.Discord.Presence.UpdatePresenceTest do
  use ExUnit.Case
  
  alias Lux.Prisms.Discord.Presence.UpdatePresence

  test "exists and has correct properties" do
    assert Lux.Prisms.Discord.Presence.UpdatePresence.name() != nil
    assert Lux.Prisms.Discord.Presence.UpdatePresence.description() != nil
  end
end
