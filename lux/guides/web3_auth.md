# Web3 Authentication and Authorization Guide

Comprehensive Web3 auth framework with SIWE, signature verification, RBAC, and session management.

## Sign-In with Ethereum (EIP-4361)

```elixir
# Create SIWE message
msg = SiweMessage.new(
  domain: "app.example.com",
  address: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
  uri: "https://app.example.com/login",
  statement: "Sign in to access your account",
  chain_id: 1
)

# Generate EIP-4361 string (send to wallet for signing)
message_str = SiweMessage.to_string(msg)

# Parse message string back
{:ok, parsed} = SiweMessage.parse(message_str)

# Validate fields (expiry, nonce, address format)
:ok = SiweMessage.validate(msg)
```

## Signature Verification

```elixir
# Verify signature matches address
:ok = SignatureVerifier.verify(message_str, signature_hex, expected_address)

# Recover signer address
{:ok, address} = SignatureVerifier.recover_address(message_str, signature_hex)
```

## Role-Based Access Control

```elixir
{:ok, pid} = RBAC.start_link()

# Define roles with permissions
RBAC.define_role(pid, :admin, [:read, :write, :delete, :manage_users])
RBAC.define_role(pid, :member, [:read, :write])
RBAC.define_role(pid, :superadmin, [:all])  # wildcard

# Assign roles
RBAC.assign_role(pid, "0xabc...", :admin)

# Check permissions
RBAC.has_permission?(pid, "0xabc...", :delete)  # => true
RBAC.authorize(pid, "0xabc...", :delete)         # => :ok

# Token gates (define balance requirements)
RBAC.add_token_gate(pid, :holder, "0xtoken...", 100)
```

## Session Management

```elixir
{:ok, pid} = SessionManager.start_link(default_ttl: 3600)

# Create session after auth
{:ok, session} = SessionManager.create_session(pid, address, %{chain_id: 1})

# Validate on each request
{:ok, _} = SessionManager.validate_session(pid, session.id)

# Refresh before expiry
{:ok, _} = SessionManager.refresh_session(pid, session.id)

# Revoke
SessionManager.revoke_session(pid, session.id)
SessionManager.revoke_all(pid, address)

# Audit log
{:ok, logs} = SessionManager.get_audit_log(pid)
```

## Full Auth Flow

```elixir
# 1. Client requests nonce
nonce = SiweMessage.generate_nonce()

# 2. Server creates SIWE message
msg = SiweMessage.new(domain: "app.com", address: addr, uri: uri, nonce: nonce)

# 3. Client signs message with wallet, returns signature

# 4. Server verifies
:ok = SiweMessage.validate(msg)
:ok = SignatureVerifier.verify(SiweMessage.to_string(msg), signature, addr)

# 5. Create session
{:ok, session} = SessionManager.create_session(sm_pid, addr)

# 6. Check permissions
:ok = RBAC.authorize(rbac_pid, addr, :required_permission)
```
