# Web3 Authentication and Authorization

Lux provides a comprehensive framework for integrating Web3 authentication and authorization into your agent workflows.

## Core Components

The framework consists of several Prisms that handle different aspects of Web3 security:

1. **SIWEPrism**: Validates Sign-In with Ethereum (EIP-4361) messages.
2. **SignaturePrism**: Validates generic EIP-191 signatures.
3. **MultiSigPrism**: Validates EIP-1271 smart contract wallet signatures.
4. **RolePrism**: Checks if an address holds a specific role in a smart contract.
5. **TokenGatePrism**: Validates if an address holds a required minimum token balance (ERC20/ERC721).
6. **SessionPrism**: Creates and validates JWT-like expiring sessions.

## Example Flow: Token-Gated Agent Access

```elixir
# 1. User signs a message to authenticate
{:ok, %{valid: true, address: address}} = Lux.Prisms.Web3Auth.SIWEPrism.run(%{
  message: siwe_message,
  signature: signature
})

# 2. Check if the user holds enough tokens to use the agent
{:ok, %{allowed: true}} = Lux.Prisms.Web3Auth.TokenGatePrism.run(%{
  contract_address: "0xTokenAddress",
  account: address,
  min_balance: "100"
})

# 3. Create a session for subsequent requests
{:ok, session} = Lux.Prisms.Web3Auth.SessionPrism.run(%{
  action: "create",
  address: address,
  ttl_seconds: 3600
})
```
