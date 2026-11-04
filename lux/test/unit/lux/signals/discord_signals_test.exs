defmodule Lux.Signals.DiscordSignalsTest do
  use UnitCase, async: true

  alias Lux.Signals.Discord.Converter
  alias Lux.Signals.Discord.MessageSignal
  alias Lux.Signals.Discord.InteractionSignal
  alias Lux.Signals.Discord.PresenceSignal
  alias Lux.Signals.Discord.VoiceSignal

  describe "Discord Signal Schemas" do
    test "instantiates MessageSignal with valid payload" do
      payload = %{
        content: "Test message",
        channel_id: "ch_123",
        guild_id: "g_456",
        author: %{id: "u_789", username: "alice"}
      }

      assert {:ok, signal} = MessageSignal.new(payload)
      assert signal.schema_id == Lux.Schemas.Discord.MessageSignalSchema
      assert signal.payload.content == "Test message"
    end

    test "instantiates InteractionSignal with valid payload" do
      payload = %{
        interaction_id: "int_999",
        type: "slash_command",
        name: "balance",
        user_id: "u_789"
      }

      assert {:ok, signal} = InteractionSignal.new(payload)
      assert signal.schema_id == Lux.Schemas.Discord.InteractionSignalSchema
    end

    test "instantiates PresenceSignal" do
      payload = %{
        user_id: "u_789",
        status: "online",
        activities: [%{name: "Lux App"}]
      }

      assert {:ok, signal} = PresenceSignal.new(payload)
      assert signal.payload.status == "online"
    end

    test "instantiates VoiceSignal" do
      payload = %{
        user_id: "u_789",
        guild_id: "g_456",
        channel_id: "v_111",
        action: "speaking",
        speaking: true
      }

      assert {:ok, signal} = VoiceSignal.new(payload)
      assert signal.payload.speaking == true
    end
  end

  describe "Lux.Signals.Discord.Converter" do
    test "converts MESSAGE_CREATE to MessageSignal" do
      raw = %{
        "content" => "Hello world",
        "channel_id" => "12345",
        "author" => %{"id" => "999", "username" => "bob"}
      }

      assert {:ok, signal} = Converter.to_signal("MESSAGE_CREATE", raw)
      assert signal.schema_id == Lux.Schemas.Discord.MessageSignalSchema
      assert signal.payload.content == "Hello world"

      assert {:ok, discord_payload} = Converter.to_discord_payload(signal)
      assert discord_payload.content == "Hello world"
    end

    test "converts INTERACTION_CREATE" do
      raw = %{
        "id" => "i_1",
        "type" => 2,
        "data" => %{"name" => "help"},
        "user" => %{"id" => "u_1"}
      }

      assert {:ok, signal} = Converter.to_signal("INTERACTION_CREATE", raw)
      assert signal.schema_id == Lux.Schemas.Discord.InteractionSignalSchema
    end
  end
end
