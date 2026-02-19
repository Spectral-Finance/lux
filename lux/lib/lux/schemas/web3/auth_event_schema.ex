defmodule Lux.Schemas.Web3.AuthEventSchema do
  @moduledoc """
  Signal schema for Web3 authentication events.

  Defines the structure for authentication-related signals that can be
  routed between agents in the Lux framework.

  ## Signal Types

    * `web3.auth.authenticated` - User successfully authenticated
    * `web3.auth.session_created` - New session created
    * `web3.auth.session_expired` - Session expired
    * `web3.auth.role_changed` - Role assignment changed
    * `web3.auth.permission_denied` - Permission check failed

  ## Example

      %Lux.Signal{
        schema_id: Lux.Schemas.Web3.AuthEventSchema,
        topic: "web3.auth.authenticated",
        payload: %{
          address: "0x71C7...",
          chain_id: 1,
          session_token: "...",
          method: "siwe"
        }
      }
  """

  use Lux.SignalSchema,
    name: "Web3 Auth Event",
    version: "1.0.0",
    description: "Schema for Web3 authentication and authorization events",
    schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "The Ethereum address involved"
        },
        chain_id: %{
          type: :integer,
          description: "The chain ID"
        },
        action: %{
          type: :string,
          description: "The auth action that occurred",
          enum: [
            "authenticated",
            "session_created",
            "session_expired",
            "session_revoked",
            "role_assigned",
            "role_revoked",
            "permission_granted",
            "permission_denied",
            "token_gate_passed",
            "token_gate_failed"
          ]
        },
        session_token: %{
          type: :string,
          description: "The session token (when applicable)"
        },
        role: %{
          type: :string,
          description: "The role involved (when applicable)"
        },
        permission: %{
          type: :string,
          description: "The permission checked (when applicable)"
        },
        metadata: %{
          type: :object,
          description: "Additional event-specific data"
        }
      },
      required: ["address", "action"]
    }
end
