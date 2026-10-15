# Web3 Authentication and Authorization Framework

Lux provides an end-to-end Web3 authentication, role-based access control (RBAC), token-gating, and security auditing framework under `Lux.Web3.Auth`.

## Key Components

1. **Sign-In with Ethereum (`Lux.Web3.Auth.SIWE`)**
   - Full EIP-4361 message construction, formatting, parsing, and temporal/domain/nonce validation.
   - Automatic replay protection via one-time challenge nonces.
2. **Cryptographic Signature Verification (`Lux.Web3.Auth.Signature`)**
   - EIP-191 (`personal_sign`) message prefixing and Keccak-256 hashing.
   - EIP-712 structured typed data hashing and signature recovery.
3. **Role-Based Access Control (`Lux.Web3.Auth.RBAC`)**
   - Hierarchical roles (`:admin` -> `:operator` -> `:trader` -> `:viewer`) with fine-grained permissions and custom role support.
4. **Token-Gated Access Control (`Lux.Web3.Auth.TokenGate`)**
   - Evaluates ERC-20, ERC-721, and ERC-1155 on-chain token ownership rules with `:all` (AND) or `:any` (OR) composition.
5. **Security Audit Logging (`Lux.Web3.Auth.AuditLog`)**
   - Bounded, queryable audit trail capturing SIWE logins, session revocations, role assignments, and authorization decisions.
6. **Agent Prism (`Lux.Prisms.Web3.AuthPrism`)**
   - Exposes Web3 authentication and authorization operations to Lux agents and workflows.
