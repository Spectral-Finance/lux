defmodule Lux.Prisms.Web3.Auth.CreateSessionPrism do
  @moduledoc """
  Issues an authenticated session token for a validated Web3 account with role bindings.
  """

  use Lux.Prism,
    name: "Create Web3 Session",
    description: "Issues a signed HMAC session bearer token for an authenticated address",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{type: :string, description: "Authenticated wallet address"},
        chain_id: %{type: :integer, description: "Chain ID session is bound to", default: 1},
        roles: %{type: :array, items: %{type: :string}, description: "Roles assigned to this session", default: ["user"]},
        ttl_seconds: %{type: :integer, description: "Session time to live in seconds", default: 86400},
        ip: %{type: :string, description: "Client IP address"},
        user_agent: %{type: :string, description: "Client User Agent"}
      },
      required: ["address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        token: %{type: :string},
        session_id: %{type: :string},
        address: %{type: :string},
        chain_id: %{type: :integer},
        expires_at: %{type: :string},
        roles: %{type: :array, items: %{type: :string}}
      },
      required: ["token", "session_id", "address", "expires_at"]
    }

  alias Lux.Web3.Auth.SessionManager

  def handler(input, _ctx) do
    address = Map.get(input, :address) || Map.get(input, "address")
    chain_id = Map.get(input, :chain_id) || Map.get(input, "chain_id", 1)
    raw_roles = Map.get(input, :roles) || Map.get(input, "roles", ["user"])
    ttl = Map.get(input, :ttl_seconds) || Map.get(input, "ttl_seconds", 86_400)
    ip = Map.get(input, :ip) || Map.get(input, "ip")
    user_agent = Map.get(input, :user_agent) || Map.get(input, "user_agent")

    roles =
      Enum.map(raw_roles, fn r ->
        if is_binary(r), do: String.to_atom(r), else: r
      end)

    opts = [
      chain_id: chain_id,
      roles: roles,
      ttl: ttl,
      ip: ip,
      user_agent: user_agent
    ]

    case SessionManager.create_session(address, opts) do
      {:ok, %{token: token, session: session}} ->
        {:ok,
         %{
           token: token,
           session_id: session.session_id,
           address: session.address,
           chain_id: session.chain_id,
           expires_at: DateTime.to_iso8601(session.expires_at),
           roles: Enum.map(session.roles, &to_string/1)
         }}

      {:error, reason} ->
        {:error, "Session creation failed: #{inspect(reason)}"}
    end
  end
end
