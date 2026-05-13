defmodule Lux.Web3.Auth.SessionTest do
  use UnitAPICase, async: true

  alias Lux.Web3.Auth.Session

  @address "0xAbCdEfAbCdEfAbCdEfAbCdEfAbCdEfAbCdEfAbCd"

  describe "issue/2" do
    test "creates a lower-cased subject with expiry" do
      session =
        Session.issue(@address, %{
          now: ~U[2026-05-13 02:00:00Z],
          ttl_seconds: 60,
          roles: [:admin],
          permissions: [:manage_agents]
        })

      assert session.subject == String.downcase(@address)
      assert session.roles == [:admin]
      assert session.permissions == [:manage_agents]
      assert session.issued_at == "2026-05-13T02:00:00Z"
      assert session.expires_at == "2026-05-13T02:01:00Z"
    end
  end

  describe "expired?/2" do
    test "detects expired sessions" do
      session = Session.issue(@address, %{now: ~U[2026-05-13 02:00:00Z], ttl_seconds: 60})

      refute Session.expired?(session, ~U[2026-05-13 02:00:30Z])
      assert Session.expired?(session, ~U[2026-05-13 02:01:00Z])
    end
  end
end
