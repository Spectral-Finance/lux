defmodule Lux.Prisms.Discord.Voice.JoinVoiceChannelTest do
  use ExUnit.Case
  
  alias Lux.Prisms.Discord.Voice.JoinVoiceChannel

  test "exists and has correct properties" do
    assert Lux.Prisms.Discord.Voice.JoinVoiceChannel.name() != nil
    assert Lux.Prisms.Discord.Voice.JoinVoiceChannel.description() != nil
  end
end
