defmodule Lux.Signals.DiscordTest do
  use ExUnit.Case, async: true
  alias Lux.Signals.Discord

  test "creates a valid message signal" do
    data = %{content: "Hello", metadata: %{channel: "123"}}
    assert {:ok, signal} = Discord.from_discord(:message, data)
    assert signal.payload.content == "Hello"
    assert signal.metadata.channel == "123"
  end

  test "fails on unknown signal type" do
    assert {:error, :unknown_signal_type} = Discord.from_discord(:unknown, %{})
  end
end