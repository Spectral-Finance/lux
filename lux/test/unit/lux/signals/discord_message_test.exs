defmodule Lux.Signals.DiscordMessageTest do
  use UnitCase, async: true

  alias Lux.Signals.DiscordMessage

  describe "new/1" do
    test "creates a valid signal with required fields" do
      attrs = %{
        payload: %{
          content: "Test message",
          channel_id: "123456789"
        }
      }

      assert {:ok, signal} = DiscordMessage.new(attrs)
      assert signal.payload.content == "Test message"
      assert signal.payload.channel_id == "123456789"
      assert is_binary(signal.id)
      assert %DateTime{} = signal.timestamp
    end

    test "validates content length" do
      attrs = %{
        payload: %{
          content: String.duplicate("a", 2001),
          channel_id: "123456789"
        }
      }

      assert {:error, _} = DiscordMessage.new(attrs)
    end

    test "requires all mandatory fields" do
      attrs1 = %{
        payload: %{
          channel_id: "123456789"
        }
      }

      assert {:error, _} = DiscordMessage.new(attrs1)

      attrs2 = %{
        payload: %{
          content: "Test message"
        }
      }

      assert {:error, _} = DiscordMessage.new(attrs2)
    end
  end
end
