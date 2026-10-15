defmodule Lux.Prisms.Web3.AuthPrism do
  @moduledoc """
  A Prism for Web3 authentication and authorization workflows.

  Supports actions:
  - `"create_challenge"`: Generates a SIWE challenge string and nonce
  - `"authenticate_siwe"`: Validates a SIWE message + signature and returns a session
  - `"verify_session"`: Validates a session token
  - `"assign_role"`: Assigns a role to an Ethereum address
  - `"authorize"`: Checks RBAC permissions and optional token gate policies
  - `"audit_entries"`: Lists security audit log entries
  """

  use Lux.Prism,
    name: "Web3 Authentication Prism",
    description:
      "Authenticates Web3 wallets via SIWE, manages RBAC roles, and enforces token gates",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action name to execute"
        },
        address: %{
          type: :string,
          description: "Ethereum wallet address (0x...)"
        },
        domain: %{
          type: :string,
          description: "RFC 3986 domain requesting authentication"
        },
        uri: %{
          type: :string,
          description: "RFC 3986 URI for SIWE challenge"
        },
        chain_id: %{
          type: :integer,
          description: "EIP-155 Chain ID"
        },
        message: %{
          type: :string,
          description: "Raw SIWE message string"
        },
        signature: %{
          type: :string,
          description: "65-byte hex signature (0x...)"
        },
        token: %{
          type: :string,
          description: "Session token identifier"
        },
        role: %{
          type: :string,
          description: "RBAC role name (admin, operator, trader, viewer)"
        },
        permission: %{
          type: :string,
          description: "Permission atom string (e.g. execute_trades, read_analytics)"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        data: %{type: :object}
      },
      required: ["status"]
    }

  alias Lux.Web3.Auth
  alias Lux.Web3.Auth.AuditLog
  alias Lux.Web3.Auth.RBAC

  @doc """
  Executes the requested Web3 authentication or authorization action.
  """
  def handler(input, _ctx) do
    action = Map.get(input, :action) || Map.get(input, "action")
    dispatch(action, input)
  end

  defp dispatch("create_challenge", input) do
    params = %{
      domain: Map.get(input, :domain, Map.get(input, "domain", "lux.spectral.finance")),
      address: Map.get(input, :address, Map.get(input, "address")),
      uri: Map.get(input, :uri, Map.get(input, "uri", "https://lux.spectral.finance/auth")),
      chain_id: Map.get(input, :chain_id, Map.get(input, "chain_id", 1))
    }

    case Auth.create_challenge(params) do
      {:ok, result} -> {:ok, %{status: "ok", data: result}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("authenticate_siwe", input) do
    message = Map.get(input, :message, Map.get(input, "message", ""))
    signature = Map.get(input, :signature, Map.get(input, "signature", ""))
    opts = Map.get(input, :opts, [])

    case Auth.authenticate_siwe(message, signature, opts) do
      {:ok, session} -> {:ok, %{status: "ok", data: session}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("verify_session", input) do
    token = Map.get(input, :token, Map.get(input, "token", ""))
    opts = Map.get(input, :opts, [])

    case Auth.verify_session(token, opts) do
      {:ok, session} -> {:ok, %{status: "ok", data: session}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("assign_role", input) do
    address = Map.get(input, :address, Map.get(input, "address", ""))
    role = normalize_atom(Map.get(input, :role, Map.get(input, "role")))
    :ok = RBAC.assign_role(address, role)
    {:ok, %{status: "ok", data: %{address: address, role: role}}}
  end

  defp dispatch("authorize", input) do
    address = Map.get(input, :address, Map.get(input, "address", ""))
    permission = normalize_atom(Map.get(input, :permission, Map.get(input, "permission")))
    opts = Map.get(input, :opts, [])

    case Auth.authorize(address, permission, opts) do
      {:ok, result} -> {:ok, %{status: "ok", data: result}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("audit_entries", input) do
    filters = Map.get(input, :filters, [])
    entries = AuditLog.list_entries(filters)
    {:ok, %{status: "ok", data: %{entries: entries}}}
  end

  defp dispatch(_unknown, _input) do
    {:error, :unsupported_action}
  end

  defp normalize_atom(val) when is_atom(val), do: val
  defp normalize_atom(val) when is_binary(val), do: String.to_atom(val)
  defp normalize_atom(_), do: :unknown
end
