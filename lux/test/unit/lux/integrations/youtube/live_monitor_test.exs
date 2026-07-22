defmodule Lux.Integrations.YouTube.LiveMonitorTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.YouTube.LiveMonitor

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "LiveMonitor transitions" do
    test "monitors and automates state transitions in dry_run mode" do
      parent = self()

      on_transition = fn new_status ->
        send(parent, {:transition, new_status})
      end

      # Start monitor in dry_run mode
      {:ok, pid} = LiveMonitor.start_link(
        broadcast_id: "mock_b_123",
        stream_id: "mock_s_456",
        poll_interval: 50,
        dry_run: true,
        on_transition: on_transition
      )

      # In dry_run, fetch_broadcast_status returns state.status (initially "ready")
      # and fetch_stream_status returns ("active", "good").
      # This should trigger ready -> testing transition.
      assert_receive {:transition, "testing"}, 500

      # Once in testing, the monitor loops and immediately transitions testing -> live.
      assert_receive {:transition, "live"}, 500

      # Verify current state via get_status
      assert {:ok, %{status: "live", stream_status: "active"}} = LiveMonitor.get_status(pid)

      # Clean up
      GenServer.stop(pid)
    end

    test "supports manual transitions via API call" do
      # Start monitor with high poll interval to avoid automated checks during manual test
      {:ok, pid} = LiveMonitor.start_link(
        broadcast_id: "mock_b_123",
        stream_id: "mock_s_456",
        poll_interval: 10000,
        dry_run: true
      )

      assert :ok = LiveMonitor.transition(pid, "testing")
      assert {:ok, %{status: "testing"}} = LiveMonitor.get_status(pid)

      assert :ok = LiveMonitor.transition(pid, "live")
      assert {:ok, %{status: "live"}} = LiveMonitor.get_status(pid)

      # Clean up
      GenServer.stop(pid)
    end
  end
end
