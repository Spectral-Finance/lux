defmodule Lux.Prisms.Discord.Voice.DetectVoiceActivityTest do
  use ExUnit.Case
  
  alias Lux.Prisms.Discord.Voice.DetectVoiceActivity

  test "exists and has correct properties" do
    assert Lux.Prisms.Discord.Voice.DetectVoiceActivity.name() != nil
    assert Lux.Prisms.Discord.Voice.DetectVoiceActivity.description() != nil
  end
end
