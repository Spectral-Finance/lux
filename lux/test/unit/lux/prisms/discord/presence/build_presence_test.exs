defmodule Lux.Prisms.Discord.Presence.BuildPresenceTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Discord.Presence.BuildPresence

  @agent_ctx %{agent: %{name: "TestAgent"}}

  describe "handler/2" do
    test "builds default presence payload" do
      {:ok, result} = BuildPresence.handler(%{}, @agent_ctx)

      assert result.payload.op == 3
      assert result.status == "online"
      assert result.activity_count == 0
    end

    test "builds presence with activities" do
      params = %{
        status: :dnd,
        activities: [%{name: "Elixir", type: :playing}]
      }

      {:ok, result} = BuildPresence.handler(params, @agent_ctx)
      assert result.status == "dnd"
      assert result.activity_count == 1
    end

    test "normalizes activity types from strings" do
      params = %{activities: [%{name: "Spotify", type: "listening"}]}
      {:ok, result} = BuildPresence.handler(params, @agent_ctx)
      assert result.activity_count == 1
    end

    test "normalizes activities with string keys" do
      params = %{activities: [%{"name" => "Game", "type" => "playing"}]}
      {:ok, result} = BuildPresence.handler(params, @agent_ctx)
      assert result.activity_count == 1
    end

    test "builds presence with since and afk" do
      params = %{since: 1_000_000, afk: true}
      {:ok, result} = BuildPresence.handler(params, @agent_ctx)
      assert result.payload.d.since == 1_000_000
      assert result.payload.d.afk == true
    end

    test "defaults missing activity type to playing" do
      params = %{activities: [%{name: "Unknown"}]}
      {:ok, result} = BuildPresence.handler(params, @agent_ctx)
      assert result.activity_count == 1
    end
  end
end
