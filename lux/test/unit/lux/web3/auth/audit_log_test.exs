defmodule Lux.Web3.Auth.AuditLogTest do
  @moduledoc """
  Tests for the AuditLog module covering event logging,
  querying with filters, and log size management.
  """

  use UnitCase

  alias Lux.Web3.Auth.AuditLog

  @test_address "0x71C7656EC7ab88b098defB751B7401B5f6d8976F"

  setup do
    table_name = :"audit_log_#{:erlang.unique_integer([:positive])}"
    name = :"audit_server_#{:erlang.unique_integer([:positive])}"

    {:ok, pid} =
      AuditLog.start_link(
        name: name,
        table_name: table_name,
        max_events: 100
      )

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    %{server: name}
  end

  describe "log/4 and query/2" do
    test "logs and retrieves an event", %{server: server} do
      AuditLog.log(:auth_success, @test_address, %{chain_id: 1}, server)

      # Small delay since log is async (cast)
      Process.sleep(10)

      events = AuditLog.query([], server)
      assert length(events) >= 1

      event = hd(events)
      assert event.action == :auth_success
      assert event.address == String.downcase(@test_address)
      assert event.metadata.chain_id == 1
    end

    test "logs multiple events", %{server: server} do
      AuditLog.log(:auth_success, @test_address, %{}, server)
      AuditLog.log(:auth_failure, @test_address, %{}, server)
      AuditLog.log(:session_created, @test_address, %{}, server)

      Process.sleep(20)

      events = AuditLog.query([], server)
      assert length(events) == 3
    end

    test "events are ordered most recent first", %{server: server} do
      AuditLog.log(:auth_success, @test_address, %{order: 1}, server)
      Process.sleep(5)
      AuditLog.log(:auth_failure, @test_address, %{order: 2}, server)
      Process.sleep(5)
      AuditLog.log(:session_created, @test_address, %{order: 3}, server)

      Process.sleep(10)

      events = AuditLog.query([], server)
      assert hd(events).action == :session_created
    end
  end

  describe "query filters" do
    test "filters by address", %{server: server} do
      other_address = "0x0000000000000000000000000000000000000001"

      AuditLog.log(:auth_success, @test_address, %{}, server)
      AuditLog.log(:auth_success, other_address, %{}, server)

      Process.sleep(10)

      events = AuditLog.query([address: @test_address], server)
      assert length(events) == 1
      assert hd(events).address == String.downcase(@test_address)
    end

    test "filters by action", %{server: server} do
      AuditLog.log(:auth_success, @test_address, %{}, server)
      AuditLog.log(:auth_failure, @test_address, %{}, server)
      AuditLog.log(:session_created, @test_address, %{}, server)

      Process.sleep(10)

      events = AuditLog.query([action: :auth_failure], server)
      assert length(events) == 1
      assert hd(events).action == :auth_failure
    end

    test "filters by time range", %{server: server} do
      AuditLog.log(:auth_success, @test_address, %{}, server)
      Process.sleep(10)

      midpoint = DateTime.utc_now()
      Process.sleep(10)

      AuditLog.log(:auth_failure, @test_address, %{}, server)
      Process.sleep(10)

      # Only events after midpoint
      events = AuditLog.query([since: midpoint], server)
      assert length(events) == 1
      assert hd(events).action == :auth_failure
    end

    test "limits result count", %{server: server} do
      for i <- 1..20 do
        AuditLog.log(:auth_success, @test_address, %{i: i}, server)
      end

      Process.sleep(30)

      events = AuditLog.query([limit: 5], server)
      assert length(events) == 5
    end

    test "combines multiple filters", %{server: server} do
      AuditLog.log(:auth_success, @test_address, %{}, server)
      AuditLog.log(:auth_failure, @test_address, %{}, server)
      AuditLog.log(:auth_success, "0x0000000000000000000000000000000000000001", %{}, server)

      Process.sleep(10)

      events =
        AuditLog.query(
          [address: @test_address, action: :auth_success],
          server
        )

      assert length(events) == 1
    end
  end

  describe "count/2" do
    test "counts matching events", %{server: server} do
      for _ <- 1..5 do
        AuditLog.log(:auth_success, @test_address, %{}, server)
      end

      AuditLog.log(:auth_failure, @test_address, %{}, server)

      Process.sleep(20)

      assert AuditLog.count([action: :auth_success], server) == 5
      assert AuditLog.count([action: :auth_failure], server) == 1
      assert AuditLog.count([], server) == 6
    end
  end

  describe "clear/1" do
    test "removes all events", %{server: server} do
      for _ <- 1..10 do
        AuditLog.log(:auth_success, @test_address, %{}, server)
      end

      Process.sleep(20)

      assert AuditLog.count([], server) == 10

      AuditLog.clear(server)

      assert AuditLog.count([], server) == 0
    end
  end

  describe "max_events trimming" do
    test "trims old events when max is exceeded" do
      table_name = :"audit_trim_#{:erlang.unique_integer([:positive])}"
      name = :"audit_trim_server_#{:erlang.unique_integer([:positive])}"

      {:ok, pid} =
        AuditLog.start_link(
          name: name,
          table_name: table_name,
          max_events: 5
        )

      for i <- 1..10 do
        AuditLog.log(:auth_success, @test_address, %{i: i}, name)
        Process.sleep(5)
      end

      Process.sleep(20)

      count = AuditLog.count([], name)
      assert count <= 5

      GenServer.stop(pid)
    end
  end
end
