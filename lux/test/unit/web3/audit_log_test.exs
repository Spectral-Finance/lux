defmodule Lux.Web3.AuditLogTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Schemas.AuditLog

  describe "create/3" do
    test "creates an audit log entry" do
      entry = AuditLog.create(:login_success, "0xabc123", %{domain: "test.com"})

      assert entry.action == :login_success
      assert entry.address == "0xabc123"
      assert entry.success == true
      assert is_map_key(entry, :id)
      assert is_map_key(entry, :timestamp)
    end

    test "marks failures correctly" do
      entry = AuditLog.create(:login_failure, "0xdef", %{reason: "bad signature"})

      assert entry.action == :login_failure
      assert entry.success == false
    end

    test "normalizes addresses to lowercase" do
      entry = AuditLog.create(:session_created, "0XABCDEF")
      assert entry.address == "0xabcdef"
    end
  end

  describe "to_map/1" do
    test "serializes entry to map" do
      entry = AuditLog.create(:signature_verified, "0xtest", %{method: :personal_sign})
      result = AuditLog.to_map(entry)

      assert is_map(result)
      assert result[:action] == :signature_verified
    end
  end

  describe "summary/1" do
    test "produces readable summary" do
      entry = AuditLog.create(:login_success, "0xabc", %{domain: "example.com"})
      summary = AuditLog.summary(entry)

      assert is_binary(summary)
      assert summary =~ "login_success"
      assert summary =~ "0xabc"
    end
  end
end
