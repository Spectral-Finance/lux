defmodule Lux.Web3.Auth.AuditLog.Test do
  use ExUnit.Case, async: true
  @moduletag :unit

  alias Lux.Web3.Auth.AuditLog

  setup do
    AuditLog.init_store()
    :ok
  end

  describe "log_auth_success/2" do
    test "records a successful authentication" do
      assert {:ok, id} = AuditLog.log_auth_success("0xaudittest1234567890abcdef1234567890abcdef12")

      entries = AuditLog.query_by_address("0xaudittest1234567890abcdef1234567890abcdef12")
      assert length(entries) == 1
      entry = List.first(entries)
      assert entry.event == :auth_success
      assert entry.id == id
    end
  end

  describe "log_auth_failure/3" do
    test "records a failed authentication" do
      assert {:ok, _id} = AuditLog.log_auth_failure("0xauditfailtestaddr12345678901234567890",
        "invalid_signature")

      entries = AuditLog.query_by_address("0xauditfailtestaddr12345678901234567890")
      assert length(entries) == 1
      entry = List.first(entries)
      assert entry.event == :auth_failure
      assert entry.details.reason == "invalid_signature"
    end
  end

  describe "log_session_created/3" do
    test "records session creation" do
      assert {:ok, _id} = AuditLog.log_session_created(
        "0xsessiontestaddr1234567890123456789012345678",
        "sess_abc123"
      )

      entries = AuditLog.query_by_event(:session_created)
      assert length(entries) >= 1
    end
  end

  describe "query_by_address/2" do
    test "returns entries for a specific address" do
      addr = "0xquerybyaddrtest1234567890123456789012345"
      AuditLog.log_auth_success(addr)
      AuditLog.log_auth_success(addr)

      entries = AuditLog.query_by_address(addr)
      assert length(entries) == 2
    end

    test "respects the limit option" do
      addr = "0xquerylimittestaddr12345678901234567890123"
      Enum.each(1..10, fn _ -> AuditLog.log_auth_success(addr) end)

      entries = AuditLog.query_by_address(addr, limit: 5)
      assert length(entries) == 5
    end
  end

  describe "query_by_event/2" do
    test "returns entries filtered by event type" do
      AuditLog.log_auth_success("0xeventtestaddr1234567890123456789012345678")
      AuditLog.log_auth_success("0xeventtestaddr21234567890123456789012345678")
      AuditLog.log_auth_failure("0xeventtestaddr31234567890123456789012345678", "bad")

      success_entries = AuditLog.query_by_event(:auth_success)
      failure_entries = AuditLog.query_by_event(:auth_failure)

      assert length(success_entries) == 2
      assert length(failure_entries) == 1
    end
  end

  describe "count/0" do
    test "returns total count of entries" do
      initial = AuditLog.count()
      AuditLog.log_auth_success("0xcounttestaddr12345678901234567890123456789")
      assert AuditLog.count() == initial + 1
    end
  end
end
