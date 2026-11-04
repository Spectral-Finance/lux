defmodule Lux.Prisms.Discord.SignalsPrismsTest do
  use UnitCase, async: true

  alias Lux.Prisms.Discord.Signals.ParseSignalPrism
  alias Lux.Prisms.Discord.Signals.ValidateSignalPrism
  alias Lux.Prisms.Discord.Signals.EmitSignalPrism
  alias Lux.Prisms.Discord.Signals.RouteSignalPrism

  describe "ParseSignalPrism" do
    test "parses raw payload into signal representation" do
      input = %{
        "event_type" => "MESSAGE_CREATE",
        "payload" => %{
          "content" => "Agent test",
          "channel_id" => "111",
          "author" => %{"id" => "u1", "username" => "tester"}
        }
      }

      assert {:ok, result} = ParseSignalPrism.handler(input, %{})
      assert result.success == true
      assert is_binary(result.signal_id)
      assert result.payload.content == "Agent test"
    end
  end

  describe "ValidateSignalPrism" do
    test "validates complete message payload" do
      input = %{
        "schema_type" => "message",
        "payload" => %{"channel_id" => "ch_1", "content" => "valid"}
      }

      assert {:ok, result} = ValidateSignalPrism.handler(input, %{})
      assert result.valid == true
      assert result.errors == []
    end

    test "flags invalid payload missing required fields" do
      input = %{
        "schema_type" => "message",
        "payload" => %{"content" => "missing channel"}
      }

      assert {:ok, result} = ValidateSignalPrism.handler(input, %{})
      assert result.valid == false
      assert length(result.errors) > 0
    end
  end

  describe "EmitSignalPrism" do
    test "formats outgoing message" do
      input = %{
        "signal_type" => "message",
        "payload" => %{"content" => "Hello out there"}
      }

      assert {:ok, result} = EmitSignalPrism.handler(input, %{})
      assert result.success == true
      assert result.discord_payload.content == "Hello out there"
    end
  end

  describe "RouteSignalPrism" do
    test "routes signal to target agent" do
      input = %{
        "signal_id" => "sig_123",
        "signal_schema" => "Lux.Schemas.Discord.MessageSignalSchema"
      }

      assert {:ok, result} = RouteSignalPrism.handler(input, %{})
      assert result.routed == true
    end
  end
end
