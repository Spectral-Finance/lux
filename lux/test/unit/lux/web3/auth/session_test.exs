defmodule Lux.Web3.Auth.SessionTest do
  use UnitCase, async: true

  alias Lux.Web3.Auth.Session

  @address "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf"
  @now ~U[2026-05-13 09:00:00Z]

  test "issues refreshes and revokes sessions with audit events" do
    session = Session.issue(@address, now: @now, ttl_seconds: 60, roles: [:viewer])

    assert session.subject == String.downcase(@address)
    assert session.roles == [:viewer]
    assert Session.valid?(session, DateTime.add(@now, 30, :second))
    assert Session.expired?(session, DateTime.add(@now, 61, :second))
    assert [%{event: :session_issued}] = session.audit_log

    refreshed = Session.refresh(session, now: DateTime.add(@now, 30, :second), ttl_seconds: 60)
    assert Session.valid?(refreshed, DateTime.add(@now, 80, :second))
    assert [%{event: :session_refreshed}, %{event: :session_issued}] = refreshed.audit_log

    revoked = Session.revoke(refreshed, now: DateTime.add(@now, 40, :second))
    assert Session.expired?(revoked, DateTime.add(@now, 41, :second))
    assert [%{event: :session_revoked} | _] = revoked.audit_log
  end
end
