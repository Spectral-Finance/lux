defmodule Lux.Prisms.Web3.Auth.AuthenticatePrism do
  @moduledoc """
  A prism for authenticating users via Sign-In with Ethereum (EIP-4361).

  This prism handles the complete SIWE authentication flow:
  1. Validates the SIWE message format
  2. Verifies the Ethereum signature
  3. Creates an authenticated session
  4. Returns session details

  ## Examples

      iex> AuthenticatePrism.handler(%{
      ...>   message: siwe_message_string,
      ...>   signature: "0x...",
      ...>   address: "0x71C7656EC7ab88b098defB751B7401B5f6d8976F"
      ...> }, %{agent: %{name: "AuthAgent"}})
      {:ok, %{
        authenticated: true,
        session_token: "...",
        address: "0x71C7...",
        chain_id: 1,
        expires_at: ~U[2024-01-01 01:00:00Z]
      }}
  """

  use Lux.Prism,
    name: "Web3 SIWE Authentication",
    description: "Authenticates a user via Sign-In with Ethereum (EIP-4361)",
    input_schema: %{
      type: :object,
      properties: %{
        message: %{
          type: :string,
          description: "The SIWE message string to verify"
        },
        signature: %{
          type: :string,
          description: "The hex-encoded Ethereum signature"
        },
        address: %{
          type: :string,
          description: "The expected signer's Ethereum address"
        },
        session_ttl: %{
          type: :integer,
          description: "Session time-to-live in seconds (default: 3600)"
        }
      },
      required: ["message", "signature", "address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        authenticated: %{type: :boolean, description: "Whether authentication succeeded"},
        session_token: %{type: :string, description: "The session token for subsequent requests"},
        address: %{type: :string, description: "The authenticated wallet address"},
        chain_id: %{type: :integer, description: "The chain ID from the SIWE message"},
        expires_at: %{type: :string, description: "Session expiry time (ISO 8601)"}
      },
      required: ["authenticated"]
    }

  alias Lux.Web3.Auth

  require Logger

  @impl true
  def handler(
        %{message: message, signature: signature, address: address} = input,
        _ctx
      ) do
    Logger.info("Attempting SIWE authentication for #{address}")

    params = %{
      message: message,
      signature: signature,
      address: address,
      session_ttl: Map.get(input, :session_ttl, 3600)
    }

    case Auth.authenticate_siwe(params) do
      {:ok, session} ->
        Logger.info("Authentication successful for #{address}")

        {:ok,
         %{
           authenticated: true,
           session_token: session.token,
           address: session.address,
           chain_id: session.chain_id,
           expires_at: DateTime.to_iso8601(session.expires_at)
         }}

      {:error, reason} ->
        Logger.warning("Authentication failed for #{address}: #{reason}")
        {:ok, %{authenticated: false, error: reason}}
    end
  end

  def handler(_params, _ctx) do
    {:error, "Missing required parameters: message, signature, address"}
  end
end
