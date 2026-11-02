defmodule Lux.Web3.Auth.AuditLoggerTest do
  use ExUnit.Case, async: false

  alias Lux.Web3.Auth.AuditLogger

  @addr "0x95222290dd7278aa3ddd389cc1e1d165cc4bafe5"

  setup do
    server_name = :"audit_logger_test_#{:erlang.unique_integer()}"
    {:ok, pid} = AuditLogger.start_link(name: server_name)
    %{server: server_name, pid: pid}
  end

  describe "log/6 and query/2" do
    test "records audit logs and filters by event_type and address", %{server: srv} do
      AuditLogger.log(:login_success, @addr, :ok, %{method: "siwe"}, [ip: "127.0.0.1"], srv)
      AuditLogger.log(:token_gate_failed, @addr, :error, %{reason: "insufficient_balance"}, [], srv)
      AuditLogger.log(:login_failure, "0x0000000000000000000000000000000000000000", :error, %{}, [], srv)

      # Query all for @addr
      addr_logs = AuditLogger.query([address: @addr], srv)
      assert length(addr_logs) == 2

      # Query only login_success
      login_logs = AuditLogger.query([event_type: :login_success], srv)
      assert length(login_logs) == 1
      assert hd(login_logs).event_type == :login_success
    end

    test "summary metrics aggregation", %{server: srv} do
      AuditLogger.log(:login_success, @addr, :ok, %{}, [], srv)
      AuditLogger.log(:access_denied, @addr, :error, %{}, [], srv)

      metrics = AuditLogger.summary(srv)
      assert metrics.total == 2
      assert metrics.by_status.ok == 1
      assert metrics.by_status.error == 1
    end
  end
end
