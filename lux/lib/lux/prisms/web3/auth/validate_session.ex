defmodule Lux.Prisms.Web3.Auth.ValidateSessionPrism do
  @moduledoc """
  Validates a Web3 session token or session ID for authenticity, expiry, and revocation.
  """

  use Lux.Prism,
    name: "Validate Web3 Session",
    description: "Validates bearer token or session ID, returning authenticated session data",
    input_schema: %{
      type: :object,
      properties: %{
        token: %{type: :string, description: "Bearer token or session ID to validate"}
      },
      required: ["token"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        valid: %{type: :boolean},
        session_id: %{type: :string},
        address: %{type: :string},
        chain_id: %{type: :integer},
        roles: %{type: :array, items: %{type: :string}}
      },
      required: ["valid", "session_id", "address"]
    }

  alias Lux.Web3.Auth.SessionManager

  def handler(input, _ctx) do
    token = Map.get(input, :token) || Map.get(input, "token")

    case SessionManager.validate_session(token) do
      {:ok, session} ->
        {:ok,
         %{
           valid: true,
           session_id: session.session_id,
           address: session.address,
           chain_id: session.chain_id,
           roles: Enum.map(session.roles, &to_string/1)
         }}

      {:error, reason} ->
        {:ok,
         %{
           valid: false,
           session_id: "",
           address: "",
           chain_id: 1,
           roles: [],
           error: to_string(reason)
         }}
    end
  end
end
