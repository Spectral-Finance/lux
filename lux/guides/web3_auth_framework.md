# Web3 Authentication and Authorization Framework

## Overview

The Lux Web3 Authentication and Authorization Framework provides an enterprise-grade security layer for decentralized applications, autonomous AI agents, and institutional smart contract workflows. It unifies cryptographic identity verification, multi-signature threshold approval, dynamic token-gated access control, and granular role-based access management (RBAC).

---

## Architecture

The framework consists of four foundational layers:

1. **Cryptographic Identity & Signatures (`Lux.Web3.Auth.SignatureVerifier`, `Lux.Web3.Auth.SIWE`):**
   - **EIP-4361 (SIWE):** Standard Sign-In with Ethereum with cryptographic nonce generation, message formatting, domain matching, and expiration verification.
   - **EIP-191 Personal Sign:** Standard Ethereum prefixed signature verification with secp256k1 recovery.
   - **EIP-712 Typed Data:** Structured typed hashing and signature verification for complex off-chain intents.
   - **ERC-1271 Smart Contract Wallets:** Multi-sig and account abstraction wallet verification (`isValidSignature` returning magic value `0x1626ba7e`).
   - **Threshold Multi-Signature:** Validates that $M$-of-$N$ authorized owners have provided non-duplicate signatures for an action.

2. **Session Lifecycle Management (`Lux.Web3.Auth.SessionManager`):**
   - Cryptographic bearer tokens signed with HMAC-SHA256 containing expiration, address, and role claims.
   - In-memory state tracking, sliding session expiration, and instant single or multi-device revocation.

3. **Role-Based Access Control (`Lux.Web3.Auth.RBAC`):**
   - Role hierarchy: `:super_admin` > `:admin` > `:agent` > `:trader` > `:user` > `:guest`.
   - Granular permissions: `:read_data`, `:execute_trades`, `:manage_orders`, `:manage_wallets`, `:administer_users`, `:mint_tokens`, `:transfer_funds`, `:call_contracts`, `:manage_prisms`, `:audit_logs`.

4. **Token-Gated Access Control (`Lux.Web3.Auth.TokenGating`):**
   - Verifies on-chain holdings: ERC-20 token balances, ERC-721 NFT ownership, ERC-1155 semi-fungible balances, and native coins across EVM chains.
   - Composite combinators (`:all`, `:any`, `:none`) for flexible governance tiers.

5. **Security Audit Logger (`Lux.Web3.Auth.AuditLogger`):**
   - Structured audit trails for logins, token gates, authorization attempts, and administrative interventions.

---

## Quickstart

### 1. EIP-4361 Sign-In with Ethereum (SIWE)

```elixir
alias Lux.Web3.Auth.SIWE
alias Lux.Web3.Auth.SignatureVerifier

# 1. Generate nonce and format SIWE message
nonce = SIWE.generate_nonce(16)
{:ok, message} = SIWE.format_message(%{
  domain: "app.lux.network",
  address: "0x95222290dd7278aa3ddd389cc1e1d165cc4bafe5",
  uri: "https://app.lux.network/login",
  statement: "Sign in to Lux AI Agent Network",
  nonce: nonce,
  issued_at: DateTime.to_iso8601(DateTime.utc_now())
})

# 2. Verify signature on client submission
{:ok, true} = SignatureVerifier.verify_personal_sign(message, signature_hex, "0x95222290dd7278aa3ddd389cc1e1d165cc4bafe5")
```

### 2. Session Management

```elixir
alias Lux.Web3.Auth.SessionManager

# Create session
{:ok, %{token: token, session: session}} = SessionManager.create_session(
  "0x95222290dd7278aa3ddd389cc1e1d165cc4bafe5",
  roles: [:trader],
  chain_id: 1,
  ttl: 86_400
)

# Validate incoming bearer token
case SessionManager.validate_session(token) do
  {:ok, session} ->
    IO.puts("Authenticated wallet: \#{session.address}")

  {:error, :session_expired} ->
    IO.puts("Token expired, please re-authenticate")

  {:error, :session_revoked} ->
    IO.puts("Session was revoked")
end
```

### 3. Role-Based Access Control (RBAC)

```elixir
alias Lux.Web3.Auth.RBAC

# Check permissions for roles
true = RBAC.has_permission?([:trader], :execute_trades)
false = RBAC.has_permission?([:guest], :execute_trades)

# Check permission for wallet address
assignments = %{
  "0x95222290dd7278aa3ddd389cc1e1d165cc4bafe5" => [:admin]
}

:ok = RBAC.authorize("0x95222290dd7278aa3ddd389cc1e1d165cc4bafe5", :manage_wallets, assignments)
```

### 4. Token-Gating Policy

```elixir
alias Lux.Web3.Auth.TokenGating

rule1 = TokenGating.erc20_rule("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48", 1_000) # 1000 USDC
rule2 = TokenGating.erc721_rule("0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d")      # NFT Holder

gate_spec = %{
  operator: :any,
  rules: [rule1, rule2]
}

{:ok, result} = TokenGating.evaluate_gate(wallet_address, gate_spec, balance_provider)
```

### 5. Executing with AuthBeam

```elixir
alias Lux.Beams.Web3.AuthBeam

{:ok, result, execution_log} = AuthBeam.run(%{
  address: "0x95222290dd7278aa3ddd389cc1e1d165cc4bafe5",
  message: "Sign in to Lux Agentic Network",
  signature: signature_hex,
  required_permission: "execute_trades",
  roles: ["trader"]
})
```

---

## Prisms Reference

| Prism Module | Description |
| :--- | :--- |
| `Lux.Prisms.Web3.Auth.CreateSIWEMessagePrism` | Formats compliant EIP-4361 message with secure nonce |
| `Lux.Prisms.Web3.Auth.VerifySignaturePrism` | Verifies personal_sign, EIP-712, ERC-1271, multisig |
| `Lux.Prisms.Web3.Auth.CreateSessionPrism` | Issues HMAC bearer tokens with role and expiry claims |
| `Lux.Prisms.Web3.Auth.ValidateSessionPrism` | Validates bearer tokens and checks revocation state |
| `Lux.Prisms.Web3.Auth.CheckTokenGatePrism` | Evaluates token-gating balance rules |
| `Lux.Prisms.Web3.Auth.AuthorizeActionPrism` | Evaluates RBAC permissions for requested actions |
