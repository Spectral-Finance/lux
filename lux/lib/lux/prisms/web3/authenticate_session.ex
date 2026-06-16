defmodule Lux.Prisms.Web3.AuthenticateSession do
  @moduledoc """
  Prism that authenticates a SIWE message and returns a Lux Web3 session.
  """

  use Lux.Prism,
    name: "Authenticate Web3 Session",
    description: "Verifies an EIP-4361 SIWE message and creates a scoped Web3 auth session",
    input_schema: %{
      type: :object,
      properties: %{
        message: %{type: :string, description: "Raw SIWE message signed by the wallet"},
        signature: %{type: :string, description: "65-byte recoverable Ethereum signature as hex"},
        domain: %{type: :string, description: "Expected SIWE domain"},
        uri: %{type: :string, description: "Expected SIWE URI"},
        nonce: %{type: :string, description: "Expected anti-replay nonce"},
        chain_ids: %{type: :array, description: "Allowed EVM chain IDs"},
        permissions: %{type: :array, description: "Session permissions to attach after authentication"},
        roles: %{type: :array, description: "Session roles to attach after authentication"},
        ttl_seconds: %{type: :integer, description: "Session lifetime in seconds"}
      },
      required: ["message", "signature"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        authenticated: %{type: :boolean},
        session: %{type: :object},
        audit_event: %{type: :object}
      },
      required: ["authenticated", "session", "audit_event"]
    }

  alias Lux.Web3.Auth.AuditLog
  alias Lux.Web3.Auth.Session
  alias Lux.Web3.Auth.Signature
  alias Lux.Web3.Auth.Siwe

  @impl true
  def handler(params, _ctx) do
    with {:ok, message} <- required(params, :message),
         {:ok, signature} <- required(params, :signature),
         {:ok, siwe} <- Siwe.validate(message, validation_opts(params)),
         {:ok, _address} <- Signature.verify(message, signature, siwe.address) do
      session =
        Session.create(siwe,
          permissions: get_value(params, :permissions, []),
          roles: get_value(params, :roles, []),
          ttl_seconds: get_value(params, :ttl_seconds, 3_600)
        )

      {:ok,
       %{
         authenticated: true,
         session: session,
         audit_event: AuditLog.event(:web3_authenticate, session, :success)
       }}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validation_opts(params) do
    [
      domain: get_value(params, :domain),
      uri: get_value(params, :uri),
      nonce: get_value(params, :nonce),
      chain_ids: get_value(params, :chain_ids)
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp required(params, key) do
    case get_value(params, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing required #{key}"}
    end
  end

  defp get_value(params, key, default \\ nil) do
    Map.get(params, key, Map.get(params, to_string(key), default))
  end
end
