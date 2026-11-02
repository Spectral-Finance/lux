defmodule Lux.YouTube.LiveStreaming.BroadcastManagerTest do
  use UnitCase, async: true

  alias Lux.YouTube.LiveStreaming.BroadcastManager

  describe "create_live_broadcast/1 and transition_broadcast/2" do
    test "creates broadcast and stream pair and transitions lifecycle" do
      params = %{
        title: "Lux 24/7 Agent Swarm Live",
        description: "Autonomous live broadcast stream",
        resolution: :res_1080p,
        latency_preference: :ultra_low
      }

      {:ok, broadcast} = BroadcastManager.create_live_broadcast(params)

      assert broadcast.status == :ready
      assert is_binary(broadcast.broadcast_id)
      assert is_binary(broadcast.stream_id)
      assert is_binary(broadcast.stream_key)
      assert is_binary(broadcast.live_chat_id)
      assert broadcast.params.resolution == :res_1080p
      assert broadcast.params.latency_preference == :ultra_low

      # Transition to testing
      {:ok, in_testing} = BroadcastManager.transition_broadcast(broadcast, :testing)
      assert in_testing.status == :testing

      # Transition to live
      {:ok, in_live} = BroadcastManager.transition_broadcast(in_testing, :live)
      assert in_live.status == :live

      # Transition to complete
      {:ok, finished} = BroadcastManager.transition_broadcast(in_live, :complete)
      assert finished.status == :complete
    end

    test "rejects invalid transitions" do
      {:ok, broadcast} = BroadcastManager.create_live_broadcast(%{})
      # Cannot transition directly from :ready to :complete
      {:error, reason} = BroadcastManager.transition_broadcast(broadcast, :complete)
      assert String.contains?(reason, "Invalid broadcast transition")
    end
  end
end
