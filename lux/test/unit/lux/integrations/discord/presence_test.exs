defmodule Lux.Integrations.Discord.PresenceTest do
  @moduledoc """
  Tests for the Discord Presence integration module.
  """

  use UnitAPICase, async: true

  alias Lux.Integrations.Discord.Presence

  describe "build_presence_update/1" do
    test "builds default presence update" do
      result = Presence.build_presence_update()
      assert result.status == "online"
      assert result.activities == []
      assert result.since == nil
      assert result.afk == false
    end

    test "builds presence with status and activities" do
      result = Presence.build_presence_update(
        status: :dnd,
        activities: [%{name: "Elixir", type: :playing}]
      )

      assert result.status == "dnd"
      assert length(result.activities) == 1
      assert hd(result.activities).name == "Elixir"
      assert hd(result.activities).type == 0
    end

    test "normalizes atom status to string" do
      assert Presence.build_presence_update(status: :idle).status == "idle"
      assert Presence.build_presence_update(status: :invisible).status == "invisible"
    end

    test "builds presence with since and afk" do
      result = Presence.build_presence_update(since: 1_000_000, afk: true)
      assert result.since == 1_000_000
      assert result.afk == true
    end
  end

  describe "gateway_presence_payload/1" do
    test "wraps presence in opcode 3 payload" do
      payload = Presence.gateway_presence_payload(status: :online)
      assert payload.op == 3
      assert payload.d.status == "online"
      assert payload.d.activities == []
    end
  end

  describe "custom_status/2" do
    test "builds basic custom status" do
      result = Presence.custom_status("Building things")
      assert result.name == "Custom Status"
      assert result.type == 4
      assert result.state == "Building things"
      refute Map.has_key?(result, :emoji)
    end

    test "builds custom status with emoji" do
      result = Presence.custom_status("Working", emoji_name: "rocket")
      assert result.state == "Working"
      assert result.emoji.name == "rocket"
      assert result.emoji.id == nil
      assert result.emoji.animated == false
    end

    test "builds custom status with custom emoji" do
      result = Presence.custom_status("Coding", emoji_name: "parrot", emoji_id: "123456")
      assert result.emoji.name == "parrot"
      assert result.emoji.id == "123456"
    end
  end

  describe "activity builders" do
    test "playing/1" do
      result = Presence.playing("Elixir")
      assert result.name == "Elixir"
      assert result.type == 0
    end

    test "streaming/2" do
      result = Presence.streaming("My Stream", "https://twitch.tv/test")
      assert result.name == "My Stream"
      assert result.type == 1
      assert result.url == "https://twitch.tv/test"
    end

    test "listening/1" do
      result = Presence.listening("Spotify")
      assert result.name == "Spotify"
      assert result.type == 2
    end

    test "watching/1" do
      result = Presence.watching("a movie")
      assert result.name == "a movie"
      assert result.type == 3
    end

    test "competing/1" do
      result = Presence.competing("in a tournament")
      assert result.name == "in a tournament"
      assert result.type == 5
    end
  end

  describe "rich_activity/3" do
    test "builds rich activity with all options" do
      result = Presence.rich_activity("Spotify", :listening,
        details: "Song Name",
        state: "Artist Name",
        large_image: "spotify:albumart",
        large_text: "Album Name",
        small_image: "spotify:small",
        small_text: "Playing",
        start: 1_609_459_200_000,
        buttons: ["Open Spotify"]
      )

      assert result.name == "Spotify"
      assert result.type == 2
      assert result.details == "Song Name"
      assert result.state == "Artist Name"
      assert result.timestamps.start == 1_609_459_200_000
      assert result.assets.large_image == "spotify:albumart"
      assert result.assets.large_text == "Album Name"
      assert result.buttons == ["Open Spotify"]
    end

    test "builds minimal rich activity" do
      result = Presence.rich_activity("Game", :playing)
      assert result.name == "Game"
      assert result.type == 0
      refute Map.has_key?(result, :url)
      refute Map.has_key?(result, :state)
      refute Map.has_key?(result, :details)
      refute Map.has_key?(result, :timestamps)
      refute Map.has_key?(result, :assets)
    end

    test "builds rich activity with timestamps" do
      result = Presence.rich_activity("Timer", :watching, start: 1_000_000, end: 2_000_000)
      assert result.timestamps.start == 1_000_000
      assert result.timestamps.end == 2_000_000
    end
  end

  describe "validate_status/1" do
    test "validates atom statuses" do
      assert {:ok, "online"} = Presence.validate_status(:online)
      assert {:ok, "dnd"} = Presence.validate_status(:dnd)
      assert {:ok, "idle"} = Presence.validate_status(:idle)
      assert {:ok, "invisible"} = Presence.validate_status(:invisible)
      assert {:ok, "offline"} = Presence.validate_status(:offline)
    end

    test "validates string statuses" do
      assert {:ok, "online"} = Presence.validate_status("online")
      assert {:ok, "dnd"} = Presence.validate_status("dnd")
    end

    test "rejects invalid statuses" do
      assert {:error, :invalid_status} = Presence.validate_status(:invalid)
      assert {:error, :invalid_status} = Presence.validate_status("invalid")
      assert {:error, :invalid_status} = Presence.validate_status(123)
    end
  end

  describe "validate_activity_type/1" do
    test "validates atom types" do
      assert {:ok, 0} = Presence.validate_activity_type(:playing)
      assert {:ok, 1} = Presence.validate_activity_type(:streaming)
      assert {:ok, 2} = Presence.validate_activity_type(:listening)
      assert {:ok, 3} = Presence.validate_activity_type(:watching)
      assert {:ok, 4} = Presence.validate_activity_type(:custom)
      assert {:ok, 5} = Presence.validate_activity_type(:competing)
    end

    test "validates integer types" do
      assert {:ok, 0} = Presence.validate_activity_type(0)
      assert {:ok, 5} = Presence.validate_activity_type(5)
    end

    test "rejects invalid types" do
      assert {:error, :invalid_activity_type} = Presence.validate_activity_type(:unknown)
      assert {:error, :invalid_activity_type} = Presence.validate_activity_type(6)
      assert {:error, :invalid_activity_type} = Presence.validate_activity_type(-1)
    end
  end

  describe "activity_types/0" do
    test "returns all activity types" do
      types = Presence.activity_types()
      assert types[:playing] == 0
      assert types[:streaming] == 1
      assert types[:listening] == 2
      assert types[:watching] == 3
      assert types[:custom] == 4
      assert types[:competing] == 5
    end
  end

  describe "valid_statuses/0" do
    test "returns all valid statuses" do
      statuses = Presence.valid_statuses()
      assert "online" in statuses
      assert "dnd" in statuses
      assert "idle" in statuses
      assert "invisible" in statuses
      assert "offline" in statuses
      assert length(statuses) == 5
    end
  end
end
