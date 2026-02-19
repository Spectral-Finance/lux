defmodule Lux.Prisms.Web3.Auth.ManageSessionPrism do
  @moduledoc """
  A prism for managing Web3 authentication sessions.

  Supports operations:
  - `validate` - Check if a session is valid
  - `refresh` - Extend a session's TTL
  - `revoke` - Revoke a specific session
  - `revoke_all` - Revoke all sessions for an address

  ## Examples

      iex> ManageSessionPrism.handler(%{
      ...>   action: "validate",
      ...>   token: "session_token_here"
      ...> }, %{})
      {:ok, %{valid: true, address: "0x71C7...", chain_id: 1, expires_at: "..."}}
  """

  use Lux.Prism,
    name: "Manage Web3 Sessions",
    description: "Manages Web3 authentication sessions (validate, refresh, revoke)",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action: validate, refresh, revoke, revoke_all",
          enum: ["validate", "refresh", "revoke", "revoke_all"]
        },
        token: %{
          type: :string,
          description: "Session token (for validate/refresh/revoke)"
        },
        address: %{
          type: :string,
          description: "Wallet address (for revoke_all)"
        },
        ttl: %{
          type: :integer,
          description: "New TTL in seconds (for refresh, default: 3600)"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        valid: %{type: :boolean},
        address: %{type: :string},
        chain_id: %{type: :integer},
        expires_at: %{type: :string}
      }
    }

  alias Lux.Web3.Auth.Session

  require Logger

  @impl true
  def handler(%{action: "validate", token: token}, _ctx) do
    case Session.get(token) do
      {:ok, session} ->
        {:ok,
         %{
           valid: true,
           address: session.address,
           chain_id: session.chain_id,
           roles: session.roles,
           expires_at: DateTime.to_iso8601(session.expires_at)
         }}

      {:error, reason} ->
        {:ok, %{valid: false, reason: reason}}
    end
  end

  def handler(%{action: "refresh", token: token} = input, _ctx) do
    ttl = Map.get(input, :ttl, 3600)

    case Session.refresh(token, ttl) do
      {:ok, session} ->
        Logger.info("Session refreshed for #{session.address}")

        {:ok,
         %{
           refreshed: true,
           address: session.address,
           expires_at: DateTime.to_iso8601(session.expires_at)
         }}

      {:error, reason} ->
        {:ok, %{refreshed: false, reason: reason}}
    end
  end

  def handler(%{action: "revoke", token: token}, _ctx) do
    Session.revoke(token)
    Logger.info("Session revoked")
    {:ok, %{revoked: true}}
  end

  def handler(%{action: "revoke_all", address: address}, _ctx) do
    Session.revoke_all(address)
    Logger.info("All sessions revoked for #{address}")
    {:ok, %{revoked_all: true, address: address}}
  end

  def handler(_params, _ctx) do
    {:error, "Invalid parameters. Required: action (validate|refresh|revoke|revoke_all)"}
  end
end
