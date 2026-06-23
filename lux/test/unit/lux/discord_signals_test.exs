defmodule Lux.DiscordSignalsTest do
  use UnitAPICase, async: true

  alias Lux.Signals.DiscordConverter
  alias Lux.Signals.DiscordMessage
  alias Lux.Signal

  describe "DiscordMessageSignal" do
    test "converts raw Discord message payload to signal successfully" do
      raw_payload = %{
        "content" => "Hello World!",
        "channel_id" => "11223344",
        "author" => %{"id" => "99887766"},
        "guild_id" => "55443322",
        "attachments" => [%{"url" => "https://my-file.png"}],
        "embeds" => [],
        "components" => []
      }

      assert {:ok, %Signal{schema_id: Lux.Schemas.DiscordMessageSchema} = signal} = DiscordConverter.to_signal(raw_payload)
      assert signal.payload["content"] == "Hello World!"
      assert signal.payload["channel_id"] == "11223344"
      assert signal.payload["author_id"] == "99887766"
      assert signal.payload["attachments"] == ["https://my-file.png"]
    end

    test "fails to convert message payload missing required fields" do
      # Missing content
      raw_payload = %{
        "channel_id" => "11223344",
        "author" => %{"id" => "99887766"}
      }
      assert {:error, _reason} = DiscordConverter.to_signal(raw_payload)
    end
  end

  describe "DiscordInteractionSignal" do
    test "converts raw interaction payload to signal successfully" do
      raw_payload = %{
        "type" => 2, # button
        "id" => "interaction_1",
        "user" => %{"id" => "user_1"},
        "data" => %{
          "custom_id" => "my_button_click"
        }
      }

      assert {:ok, %Signal{schema_id: Lux.Schemas.DiscordInteractionSchema} = signal} = DiscordConverter.to_signal(raw_payload)
      assert signal.payload["type"] == "button"
      assert signal.payload["id"] == "interaction_1"
      assert signal.payload["custom_id"] == "my_button_click"
    end
  end

  describe "DiscordPresenceSignal" do
    test "converts presence update payload to signal successfully" do
      raw_payload = %{
        "user" => %{"id" => "user_2"},
        "status" => "online",
        "activities" => [%{"name" => "Playing Lux"}]
      }

      assert {:ok, %Signal{schema_id: Lux.Schemas.DiscordPresenceSchema} = signal} = DiscordConverter.to_signal(raw_payload)
      assert signal.payload["user_id"] == "user_2"
      assert signal.payload["status"] == "online"
      assert hd(signal.payload["activities"])["name"] == "Playing Lux"
    end
  end

  describe "Bidirectional: to_discord_payload/1" do
    test "converts DiscordMessage signal back to Discord API request payload" do
      {:ok, signal} = DiscordMessage.new(%{
        payload: %{
          "content" => "Outbound message",
          "channel_id" => "1",
          "author_id" => "2"
        }
      })

      assert {:ok, discord_payload} = DiscordConverter.to_discord_payload(signal)
      assert discord_payload.content == "Outbound message"
      assert discord_payload.embeds == []
    end
  end
end
