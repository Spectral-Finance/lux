defmodule Lux.Beams.Web3.AuthBeam do
  @moduledoc """
  Web3 Authentication and Authorization Beam orchestrating the complete lifecycle:
  1. Signature verification (Personal Sign, SIWE, EIP-712, ERC-1271)
  2. Role-based permission evaluation (RBAC)
  3. Session token issuance
  """

  use Lux.Beam,
    name: "Web3 Auth Beam",
    description: "Orchestrates signature verification, RBAC authorization, and session creation",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{type: :string, description: "Wallet address of signer"},
        message: %{type: :string, description: "Personal sign or SIWE message"},
        signature: %{type: :string, description: "Hex signature string"},
        required_permission: %{type: :string, description: "Permission required to access resources", default: "read_data"},
        roles: %{type: :array, items: %{type: :string}, description: "Assigned roles", default: ["user"]}
      },
      required: ["address", "message", "signature"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        authenticated: %{type: :boolean},
        address: %{type: :string},
        token: %{type: :string},
        session_id: %{type: :string},
        authorized: %{type: :boolean}
      },
      required: ["authenticated", "address"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Web3.Auth.VerifySignaturePrism
  alias Lux.Prisms.Web3.Auth.AuthorizeActionPrism
  alias Lux.Prisms.Web3.Auth.CreateSessionPrism

  sequence do
    step(:verify_sig, VerifySignaturePrism, %{
      address: [:input, :address],
      message: [:input, :message],
      signature: [:input, :signature]
    })

    step(:authorize, AuthorizeActionPrism, %{
      address: [:input, :address],
      roles: [:input, :roles],
      required_permission: [:input, :required_permission]
    })

    step(:create_session, CreateSessionPrism, %{
      address: [:input, :address],
      roles: [:input, :roles]
    })

    step(:return, Lux.Prisms.NoOp, %{
      authenticated: [:steps, :verify_sig, :result, :valid],
      address: [:input, :address],
      authorized: [:steps, :authorize, :result, :authorized],
      token: [:steps, :create_session, :result, :token],
      session_id: [:steps, :create_session, :result, :session_id]
    })
  end
end
