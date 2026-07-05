defmodule Lux.Prisms.Discord.Voice.PlayMusicTest do
  use ExUnit.Case
  
  alias Lux.Prisms.Discord.Voice.PlayMusic

  test "exists and has correct properties" do
    assert Lux.Prisms.Discord.Voice.PlayMusic.name() != nil
    assert Lux.Prisms.Discord.Voice.PlayMusic.description() != nil
  end
end
