# Web3 Authentication and Authorization Framework

Lux provides a comprehensive Web3 authentication and authorization framework that integrates with the agent ecosystem. This guide covers setup, authentication flows, authorization patterns, and integration with Lux agents.

## Overview

The framework implements:

- **EIP-4361 (SIWE)** — Sign-In with Ethereum standard
- **Signature Verification** — EIP-191 personal_sign and EIP-712 typed data
- **Multi-Signature** — M-of-N threshold signature authentication
- **Session Management** — ETS-backed sessions with TTL and refresh
- **Role-Based Access Control (RBAC)** — Hierarchical roles and permissions
- **Token Gating** — Access control based on token holdings (ERC-20, ERC-721, ERC-1155)
- **Audit Logging** — Immutable event log for security events
- **Multi-Chain Support** — Ethereum, Polygon, Arbitrum, Base, and more

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Lux.Web3.Auth                         │
│  (Main entry point — orchestrates authentication)       │
├─────────────┬──────────────┬────────────┬───────────────┤
│ SIWEMessage │ SignatureVerifier │ Session  │  AuditLog   │
│ (EIP-4361)  │ (EIP-191/712)    │ (ETS)    │  (Events)   │
├─────────────┼──────────────┼────────────┼───────────────┤
│   RBAC      │  TokenGate   │ MultiSig   │              │
│ (Roles)     │ (Token Gate) │ (M-of-N)   │              │
└─────────────┴──────────────┴────────────┴───────────────┘
```

## Quick Start

### 1. Add Auth Services to Your Supervision Tree

```elixir
# In your application.ex or supervisor
children = Lux.Web3.Auth.child_specs()
Supervisor.start_link(children, strategy: :one_for_one)
```

Or add individual services:

```elixir
children = [
  {Lux.Web3.Auth.Session, []},
  {Lux.Web3.Auth.RBAC, []},
  {Lux.Web3.Auth.AuditLog, []}
]
```

### 2. Authenticate a User

```elixir
# Using the SIWE authentication flow
{:ok, session} = Lux.Web3.Auth.authenticate_siwe(%{
  message: siwe_message_string,
  signature: "0x...",
  address: "0x71C7656EC7ab88b098defB751B7401B5f6d8976F"
})

# session contains:
# %{
#   token: "abc123...",
#   address: "0x71C7...",
#   chain_id: 1,
#   roles: [],
#   created_at: ~U[2024-01-01 00:00:00Z],
#   expires_at: ~U[2024-01-01 01:00:00Z],
#   metadata: %{domain: "example.com", ...}
# }
```

### 3. Check Authorization

```elixir
# Check if a session has permission for an action
Lux.Web3.Auth.authorized?(session.token, "agents:read")
# => true or false
```

## Authentication Flows

### Sign-In with Ethereum (SIWE / EIP-4361)

SIWE is the primary authentication method. The flow is:

1. **Generate a nonce** on the server:
   ```elixir
   nonce = Lux.Web3.Auth.SIWEMessage.generate_nonce()
   ```

2. **Create a SIWE message** (typically done client-side):
   ```elixir
   {:ok, msg} = Lux.Web3.Auth.SIWEMessage.new(%{
     domain: "myapp.example.com",
     address: "0x71C7656EC7ab88b098defB751B7401B5f6d8976F",
     statement: "Sign in to MyApp",
     uri: "https://myapp.example.com/login",
     version: "1",
     chain_id: 1,
     nonce: nonce,
     issued_at: DateTime.utc_now(),
     expiration_time: DateTime.add(DateTime.utc_now(), 300, :second)
   })

   message_string = Lux.Web3.Auth.SIWEMessage.to_string(msg)
   ```

3. **User signs** with their wallet (MetaMask, WalletConnect, etc.)

4. **Verify and create session**:
   ```elixir
   {:ok, session} = Lux.Web3.Auth.authenticate_siwe(%{
     message: message_string,
     signature: "0x...",
     address: "0x71C7656EC7ab88b098defB751B7401B5f6d8976F"
   })
   ```

### Direct Signature Verification

For simpler authentication flows:

```elixir
alias Lux.Web3.Auth.SignatureVerifier

# Verify a personal_sign signature
{:ok, true} = SignatureVerifier.verify_signature(message, signature, address)

# Recover the signing address
{:ok, address} = SignatureVerifier.recover_address(message, signature)

# Verify EIP-712 typed data
{:ok, true} = SignatureVerifier.verify_typed_data(typed_data_hash, signature, address)
```

### Multi-Signature Authentication

For operations requiring multiple approvals:

```elixir
alias Lux.Web3.Auth.MultiSig

# Create a multi-sig request (2-of-3)
{:ok, request} = MultiSig.create_request(%{
  message: "Approve deployment of Agent X",
  signers: [addr1, addr2, addr3],
  threshold: 2,
  ttl: 3600
})

# Collect signatures
{:ok, %{complete: false}} = MultiSig.add_signature(request.id, addr1, sig1)
{:ok, %{complete: true}}  = MultiSig.add_signature(request.id, addr2, sig2)
```

## Authorization

### Role-Based Access Control (RBAC)

The RBAC system comes with built-in roles and supports custom role definitions:

#### Built-in Roles

| Role | Permissions |
|------|-------------|
| `admin` | `*:*` (full access) |
| `operator` | Read, write, execute on agents, beams, prisms, lenses |
| `viewer` | Read-only access to all resources |

#### Custom Roles

```elixir
alias Lux.Web3.Auth.RBAC

# Define a custom role
RBAC.define_role(:agent_manager, %{
  permissions: ["agents:read", "agents:write", "agents:execute", "beams:read"],
  description: "Can manage agents and read beams"
})

# Define a role with inheritance
RBAC.define_role(:senior_operator, %{
  permissions: ["admin:view_logs"],
  parent: :operator,  # Inherits all operator permissions
  description: "Operator with log access"
})

# Assign a role to a wallet
RBAC.assign_role("0x71C7...", :agent_manager)

# Check permissions
RBAC.has_permission?("0x71C7...", "agents:write")  # => true
RBAC.has_permission?("0x71C7...", "admin:manage")   # => false
```

#### Permission Format

Permissions use a `resource:action` format with wildcard support:

- `"agents:read"` — Read access to agents
- `"agents:*"` — All actions on agents
- `"*:read"` — Read access to all resources
- `"*:*"` — Full admin access

### Token Gating

Control access based on token ownership:

```elixir
alias Lux.Web3.Auth.TokenGate

# Define token requirements
{:ok, usdc_rule} = TokenGate.build_rule(%{
  contract: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
  chain_id: 1,
  type: :erc20,
  min_balance: 1000,
  role: :usdc_holder
})

{:ok, nft_rule} = TokenGate.build_rule(%{
  contract: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
  chain_id: 1,
  type: :erc721,
  min_balance: 1,
  role: :bayc_holder
})

# Check access (AND logic — all rules must pass)
{:ok, result} = TokenGate.check_access(address, [usdc_rule, nft_rule], balance_checker)
# result.passed => true/false
# result.roles => [:usdc_holder, :bayc_holder]

# Check access (OR logic — any rule can pass)
{:ok, result} = TokenGate.check_access_any(address, [usdc_rule, nft_rule], balance_checker)
```

## Session Management

```elixir
alias Lux.Web3.Auth.Session

# Sessions are created automatically by authenticate_siwe/1
# You can also create them directly:
{:ok, session} = Session.create(%{
  address: "0x71C7...",
  chain_id: 1,
  ttl: 3600,
  roles: ["operator"],
  metadata: %{app: "myapp"}
})

# Validate a session
{:ok, session} = Session.get(token)

# Refresh (extend TTL)
{:ok, session} = Session.refresh(token, 7200)

# Revoke a single session
Session.revoke(token)

# Revoke all sessions for an address
Session.revoke_all("0x71C7...")

# List active sessions
sessions = Session.list_by_address("0x71C7...")

# Update roles on a session
{:ok, session} = Session.update_roles(token, ["admin", "operator"])
```

## Audit Logging

All authentication and authorization events are automatically logged:

```elixir
alias Lux.Web3.Auth.AuditLog

# Query events
events = AuditLog.query(
  address: "0x71C7...",
  action: :auth_success,
  since: ~U[2024-01-01 00:00:00Z],
  limit: 50
)

# Count events
count = AuditLog.count(action: :auth_failure)
```

### Logged Event Types

| Event | Description |
|-------|-------------|
| `:auth_success` | Successful authentication |
| `:auth_failure` | Failed authentication attempt |
| `:session_created` | New session created |
| `:session_refreshed` | Session TTL extended |
| `:session_revoked` | Session explicitly revoked |
| `:role_assigned` | Role assigned to address |
| `:role_revoked` | Role removed from address |
| `:permission_granted` | Permission check passed |
| `:permission_denied` | Permission check failed |
| `:token_gate_passed` | Token gate requirement met |
| `:token_gate_failed` | Token gate requirement not met |

## Using with Lux Agents

### Authentication Prism

```elixir
# Use in an agent's prism list
defmodule MyApp.AuthAgent do
  use Lux.Agent,
    name: "Auth Agent",
    prisms: [
      Lux.Prisms.Web3.Auth.AuthenticatePrism,
      Lux.Prisms.Web3.Auth.VerifySignaturePrism,
      Lux.Prisms.Web3.Auth.ManageRolesPrism,
      Lux.Prisms.Web3.Auth.ManageSessionPrism
    ]
end
```

### Role Management Prism

```elixir
# Assign a role via prism
Lux.Prisms.Web3.Auth.ManageRolesPrism.handler(%{
  action: "assign",
  address: "0x71C7...",
  role: "operator"
}, %{})

# Check permission
Lux.Prisms.Web3.Auth.ManageRolesPrism.handler(%{
  action: "check",
  address: "0x71C7...",
  permission: "agents:execute"
}, %{})
```

### Audit Log Lens

```elixir
# Query audit events via lens
Lux.Lenses.Web3.Auth.AuditLogLens.focus(%{
  address: "0x71C7...",
  action: "auth_success",
  limit: 10
})
```

## Multi-Chain Support

The framework supports multiple EVM-compatible chains:

| Chain ID | Network |
|----------|---------|
| 1 | Ethereum Mainnet |
| 5 | Goerli Testnet |
| 10 | Optimism |
| 56 | BNB Smart Chain |
| 100 | Gnosis Chain |
| 137 | Polygon |
| 8453 | Base |
| 42161 | Arbitrum One |
| 43114 | Avalanche C-Chain |
| 11155111 | Sepolia Testnet |

```elixir
# Check chain support
Lux.Web3.Auth.chain_supported?(137)  # => true

# Get supported chains
Lux.Web3.Auth.supported_chains()
```

## Security Considerations

1. **Nonce Management** — Always generate and verify nonces server-side to prevent replay attacks
2. **Message Expiry** — Set short expiration times on SIWE messages (5-10 minutes)
3. **Session TTL** — Use appropriate session timeouts (1-24 hours depending on sensitivity)
4. **Audit Trail** — Monitor audit logs for suspicious patterns (repeated failures, unusual chains)
5. **Token Gate Caching** — Cache token balance checks to avoid excessive RPC calls
6. **Multi-Sig Threshold** — Use appropriate thresholds for critical operations
