defmodule Lux.Signals.DiscordSignalsTest do
  use UnitCase, async: true

  alias Lux.Schemas.{DiscordInteractionSchema, DiscordMessageSchema, DiscordPresenceSchema}
  alias Lux.Signals.{DiscordInteraction, DiscordMessage, DiscordPresence}

  describe "DiscordMessageSchema & Signal" do
    test "defines valid schema attributes" do
      schema = DiscordMessageSchema.view()
      assert schema.name == "discord.message"
      assert schema.version == "1.0.0"
      assert "channel_id" in schema.schema["required"]
      assert "content" in schema.schema["required"]
    end

    test "parses raw Discord message event into Lux.Signal" do
      raw_event = %{
        "id" => "1234567890",
        "channel_id" => "9876543210",
        "guild_id" => "1122334455",
        "content" => "Hello, Lux Agent!",
        "author" => %{
          "id" => "5544332211",
          "username" => "lux_user",
          "discriminator" => "0001",
          "bot" => false
        },
        "attachments" => [
          %{
            "id" => "998877",
            "filename" => "data.csv",
            "url" => "https://cdn.discordapp.com/attachments/998877/data.csv",
            "size" => 1024,
            "content_type" => "text/csv"
          }
        ],
        "embeds" => [
          %{
            "title" => "Embed Title",
            "description" => "Embed description",
            "fields" => [
              %{"name" => "Key", "value" => "Value", "inline" => true}
            ]
          }
        ],
        "components" => [],
        "timestamp" => "2026-11-02T12:00:00Z"
      }

      assert {:ok, signal} = DiscordMessage.from_event(raw_event)
      assert signal.topic == "discord.message.9876543210"
      assert signal.sender == "lux_user"
      assert signal.payload["content"] == "Hello, Lux Agent!"
      assert signal.payload["channel_id"] == "9876543210"
      assert signal.payload["author"]["id"] == "5544332211"
      assert length(signal.payload["attachments"]) == 1
      assert length(signal.payload["embeds"]) == 1

      # Bidirectional conversion back to Discord event
      event = DiscordMessage.to_event(signal)
      assert event["content"] == "Hello, Lux Agent!"
      assert event["channel_id"] == "9876543210"
      assert event["author"]["username"] == "lux_user"
    end
  end

  describe "DiscordInteractionSchema & Signal" do
    test "defines valid schema attributes" do
      schema = DiscordInteractionSchema.view()
      assert schema.name == "discord.interaction"
      assert "id" in schema.schema["required"]
      assert "type" in schema.schema["required"]
      assert "token" in schema.schema["required"]
    end

    test "parses raw Discord interaction event into Lux.Signal" do
      raw_interaction = %{
        "id" => "9988112233",
        "application_id" => "11229988",
        "type" => 2,
        "token" => "inter_tok_xyz123",
        "channel_id" => "9876543210",
        "guild_id" => "1122334455",
        "data" => %{
          "name" => "analyze_market",
          "options" => [%{"name" => "symbol", "value" => "ETH"}]
        },
        "member" => %{
          "user" => %{
            "id" => "33221144",
            "username" => "trader_bob"
          }
        }
      }

      assert {:ok, signal} = DiscordInteraction.from_event(raw_interaction)
      assert signal.topic == "discord.interaction.9988112233"
      assert signal.payload["type_name"] == "application_command"
      assert signal.payload["data"]["name"] == "analyze_market"
      assert signal.payload["user"]["username"] == "trader_bob"

      # Bidirectional conversion back to Discord event
      event = DiscordInteraction.to_event(signal)
      assert event["id"] == "9988112233"
      assert event["type"] == 2
      assert event["token"] == "inter_tok_xyz123"
    end
  end

  describe "DiscordPresenceSchema & Signal" do
    test "defines valid schema attributes" do
      schema = DiscordPresenceSchema.view()
      assert schema.name == "discord.presence"
      assert "user_id" in schema.schema["required"]
      assert "status" in schema.schema["required"]
    end

    test "parses raw Discord presence update into Lux.Signal" do
      raw_presence = %{
        "user" => %{"id" => "7788990011"},
        "guild_id" => "1122334455",
        "status" => "online",
        "activities" => [
          %{
            "name" => "Visual Studio Code",
            "type" => 0,
            "state" => "Coding Elixir agents"
          }
        ],
        "client_status" => %{
          "desktop" => "online"
        }
      }

      assert {:ok, signal} = DiscordPresence.from_event(raw_presence)
      assert signal.topic == "discord.presence.7788990011"
      assert signal.payload["status"] == "online"
      assert signal.payload["user_id"] == "7788990011"
      assert length(signal.payload["activities"]) == 1

      # Bidirectional conversion back to Discord event
      event = DiscordPresence.to_event(signal)
      assert event["status"] == "online"
      assert event["user"]["id"] == "7788990011"
      assert hd(event["activities"])["name"] == "Visual Studio Code"
    end
  end
end
