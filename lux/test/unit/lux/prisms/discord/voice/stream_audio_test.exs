defmodule Lux.Prisms.Discord.Voice.StreamAudioTest do
  use ExUnit.Case
  
  alias Lux.Prisms.Discord.Voice.StreamAudio

  test "exists and has correct properties" do
    assert Lux.Prisms.Discord.Voice.StreamAudio.name() != nil
    assert Lux.Prisms.Discord.Voice.StreamAudio.description() != nil
  end
end
