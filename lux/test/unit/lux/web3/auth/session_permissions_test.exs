defmodule Lux.Web3.Auth.SessionPermissionsTest do
  use UnitCase, async: true

  alias Lux.Web3.Auth.Permissions
  alias Lux.Web3.Auth.Session
  alias Lux.Web3.Auth.TokenGate

  @siwe %{
    address: "0x71c7656ec7ab88b098defb751b7401b5f6d8976f",
    domain: "app.example.com",
    uri: "https://app.example.com/login",
    chain_id: 1,
    nonce: "n-123456",
    resources: []
  }

  test "creates active sessions with permissions and roles" do
    session =
      Session.create(@siwe,
        permissions: ["orders:read"],
        roles: ["trader"],
        now: ~U[2026-06-15 10:00:00Z],
        ttl_seconds: 60
      )

    assert Session.active?(session, ~U[2026-06-15 10:00:30Z])
    refute Session.active?(session, ~U[2026-06-15 10:01:00Z])
    assert Session.has_permission?(session, "orders:read")
    assert Session.has_role?(session, "trader")
  end

  test "authorizes direct and role-granted permissions" do
    session = Session.create(@siwe, permissions: ["orders:read"], roles: ["trader"])
    policy = %{roles: %{"trader" => ["orders:write"]}}

    assert {:ok, :authorized} = Permissions.authorize(session, "orders:read", policy)
    assert {:ok, :authorized} = Permissions.authorize(session, "orders:write", policy)
    assert {:error, "Missing required permission admin:write"} = Permissions.authorize(session, "admin:write", policy)
  end

  test "evaluates token gates through caller-supplied balance fetcher" do
    session = Session.create(@siwe)
    rules = [%{chain_id: 1, contract: "0xtoken", min_balance: 2}]
    address = @siwe.address
    balance_fetcher = fn 1, "0xtoken", ^address -> {:ok, 3} end

    assert {:ok, :authorized} = TokenGate.authorize(session, rules, balance_fetcher)
  end
end
