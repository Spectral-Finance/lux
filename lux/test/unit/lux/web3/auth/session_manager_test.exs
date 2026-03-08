defmodule Lux.Web3.Auth.SessionManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Auth.SessionManager

  @addr "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"

  setup do
    name = :"session_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = SessionManager.start_link(name: name, default_ttl: 3600)
    %{pid: pid}
  end

  test "create and get session", %{pid: pid} do
    {:ok, session} = SessionManager.create_session(pid, @addr, %{chain_id: 1})
    assert session.address == String.downcase(@addr)
    {:ok, found} = SessionManager.get_session(pid, session.id)
    assert found.id == session.id
  end

  test "validate active session", %{pid: pid} do
    {:ok, session} = SessionManager.create_session(pid, @addr)
    {:ok, _} = SessionManager.validate_session(pid, session.id)
  end

  test "validate expired session", %{pid: pid} do
    name = :"session_short_#{:rand.uniform(1_000_000)}"
    {:ok, short_pid} = SessionManager.start_link(name: name, default_ttl: 0)
    {:ok, session} = SessionManager.create_session(short_pid, @addr)
    Process.sleep(10)
    assert {:error, :expired} = SessionManager.validate_session(short_pid, session.id)
  end

  test "refresh session", %{pid: pid} do
    {:ok, session} = SessionManager.create_session(pid, @addr)
    {:ok, refreshed} = SessionManager.refresh_session(pid, session.id)
    assert refreshed.expires_at >= session.expires_at
  end

  test "revoke session", %{pid: pid} do
    {:ok, session} = SessionManager.create_session(pid, @addr)
    :ok = SessionManager.revoke_session(pid, session.id)
    assert {:error, :not_found} = SessionManager.get_session(pid, session.id)
  end

  test "revoke all sessions for address", %{pid: pid} do
    {:ok, _} = SessionManager.create_session(pid, @addr)
    {:ok, _} = SessionManager.create_session(pid, @addr)
    {:ok, count} = SessionManager.revoke_all(pid, @addr)
    assert count == 2
    {:ok, active} = SessionManager.active_sessions(pid)
    assert active == []
  end

  test "audit log records events", %{pid: pid} do
    {:ok, session} = SessionManager.create_session(pid, @addr)
    :ok = SessionManager.revoke_session(pid, session.id)
    {:ok, logs} = SessionManager.get_audit_log(pid)
    assert length(logs) >= 2
    assert Enum.any?(logs, &(&1.event == :session_created))
    assert Enum.any?(logs, &(&1.event == :session_revoked))
  end

  test "active sessions count", %{pid: pid} do
    {:ok, _} = SessionManager.create_session(pid, @addr)
    {:ok, _} = SessionManager.create_session(pid, "0x" <> String.duplicate("b", 40))
    {:ok, active} = SessionManager.active_sessions(pid)
    assert length(active) == 2
  end

  test "not found returns error", %{pid: pid} do
    assert {:error, :not_found} = SessionManager.get_session(pid, "nonexistent")
    assert {:error, :not_found} = SessionManager.validate_session(pid, "nonexistent")
  end
end
