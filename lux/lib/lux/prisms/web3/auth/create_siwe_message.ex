defmodule Lux.Prisms.Web3.Auth.CreateSIWEMessagePrism do
  @moduledoc """
  Generates a standard EIP-4361 Sign-In with Ethereum (SIWE) message and cryptographically secure nonce.
  """

  use Lux.Prism,
    name: "Create SIWE Message",
    description: "Generates an EIP-4361 compliant SIWE message and nonce for Ethereum login",
    input_schema: %{
      type: :object,
      properties: %{
        domain: %{type: :string, description: "RFC 3986 authority domain requesting the signing"},
        address: %{type: :string, description: "Ethereum address performing the signing (0x...)"},
        uri: %{type: :string, description: "RFC 3986 URI referring to resource subject of the sign-in"},
        statement: %{type: :string, description: "Human-readable assertion that the user is signing"},
        chain_id: %{type: :integer, description: "EIP-155 Chain ID to which the session is bound", default: 1},
        ttl_seconds: %{type: :integer, description: "Seconds until message expires", default: 300},
        resources: %{type: :array, items: %{type: :string}, description: "List of resource URIs"}
      },
      required: ["domain", "address", "uri"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        nonce: %{type: :string},
        message: %{type: :string},
        issued_at: %{type: :string},
        expiration_time: %{type: :string}
      },
      required: ["nonce", "message", "issued_at"]
    }

  alias Lux.Web3.Auth.SIWE

  def handler(input, _ctx) do
    domain = Map.get(input, :domain) || Map.get(input, "domain")
    address = Map.get(input, :address) || Map.get(input, "address")
    uri = Map.get(input, :uri) || Map.get(input, "uri")
    statement = Map.get(input, :statement) || Map.get(input, "statement")
    chain_id = Map.get(input, :chain_id) || Map.get(input, "chain_id", 1)
    ttl = Map.get(input, :ttl_seconds) || Map.get(input, "ttl_seconds", 300)
    resources = Map.get(input, :resources) || Map.get(input, "resources", [])

    nonce = SIWE.generate_nonce(16)
    now = DateTime.utc_now()
    issued_at = DateTime.to_iso8601(now)
    expiration_time = DateTime.to_iso8601(DateTime.add(now, ttl, :second))

    params = %{
      domain: domain,
      address: address,
      uri: uri,
      statement: statement,
      chain_id: chain_id,
      nonce: nonce,
      issued_at: issued_at,
      expiration_time: expiration_time,
      resources: resources
    }

    case SIWE.format_message(params) do
      {:ok, formatted_message} ->
        {:ok,
         %{
           nonce: nonce,
           message: formatted_message,
           issued_at: issued_at,
           expiration_time: expiration_time
         }}

      {:error, reason} ->
        {:error, "SIWE message creation failed: #{inspect(reason)}"}
    end
  end
end
