# Web3 Authentication and Authorization

Lux includes a small, storage-agnostic Web3 authentication layer for EIP-4361 Sign-In with Ethereum (SIWE) flows.

## Modules

- `Lux.Web3.Auth.Siwe` parses and validates SIWE messages, including domain, URI, chain ID, nonce, expiration, and not-before checks.
- `Lux.Web3.Auth.Signature` verifies Ethereum personal-sign signatures by recovering the signer and comparing it to the SIWE address.
- `Lux.Web3.Auth.Session` creates scoped session maps with roles, permissions, resources, and expiry.
- `Lux.Web3.Auth.Permissions` evaluates direct permissions and role-based grants.
- `Lux.Web3.Auth.TokenGate` evaluates token-gating policies with a caller-provided balance function.
- `Lux.Web3.Auth.AuditLog` builds structured, redacted audit events.
- `Lux.Prisms.Web3.AuthenticateSession` wraps the flow as a Lux prism.

## Prism Example

```elixir
{:ok, result} =
  Lux.Prisms.Web3.AuthenticateSession.run(%{
    message: raw_siwe_message,
    signature: wallet_signature,
    domain: "app.example.com",
    uri: "https://app.example.com/login",
    nonce: stored_nonce,
    chain_ids: [1, 10, 137],
    permissions: ["orders:read"],
    roles: ["trader"],
    ttl_seconds: 3600
  })

session = result.session
```

## Authorization Example

```elixir
policy = %{
  roles: %{
    "admin" => ["*"],
    "trader" => ["orders:read", "orders:write"]
  }
}

Lux.Web3.Auth.Permissions.authorize(session, "orders:write", policy)
```

## Token-Gating Example

```elixir
rules = [
  %{chain_id: 1, contract: "0x0000000000000000000000000000000000000000", min_balance: 1}
]

balance_fetcher = fn chain_id, contract, address ->
  MyApp.TokenBalances.fetch(chain_id, contract, address)
end

Lux.Web3.Auth.TokenGate.authorize(session, rules, balance_fetcher)
```
