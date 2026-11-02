defmodule Lux.YouTube.LiveStreaming.MultiStreamControllerTest do
  use UnitCase, async: true

  alias Lux.YouTube.LiveStreaming.MultiStreamController

  describe "check_and_failover/3" do
    test "triggers automated failover when primary stream degrades" do
      state = MultiStreamController.init_controller("stream_primary", "stream_backup")
      assert state.active_stream == :primary
      assert state.failover_occurred == false

      # Simulate primary degradation (bitrate drops to 500kbps) while backup is healthy (6000kbps)
      primary_tel = %{bitrate_kbps: 500}
      backup_tel = %{bitrate_kbps: 6000}

      updated = MultiStreamController.check_and_failover(state, primary_tel, backup_tel)

      assert updated.active_stream == :backup
      assert updated.failover_occurred == true
      assert updated.primary.status == :degraded
      assert updated.backup.status == :healthy
      assert is_binary(updated.last_switch_timestamp)
    end
  end
end
