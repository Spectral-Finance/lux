defmodule Lux.Prisms.Web3Auth.SessionPrism do
  @moduledoc """
  A prism that creates and validates sessions based on authentication results.
  """
  use Lux.Prism,
    name: "Session Manager",
    description: "Creates and validates expiring sessions",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, description: "'create' or 'validate'"},
        address: %{type: :string, description: "The authenticated address (for create)"},
        ttl_seconds: %{type: :integer, description: "Time to live in seconds (for create)"},
        token: %{type: :string, description: "The session token (for validate)"}
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        valid: %{type: :boolean, description: "Whether the session is valid"},
        token: %{type: :string, description: "The generated session token"},
        address: %{type: :string, description: "The address associated with the session"},
        expires_at: %{type: :integer, description: "Unix timestamp of expiry"},
        error: %{type: :string, description: "Error message if failed"}
      },
      required: []
    }

  def handler(input, _ctx) do
    action = Map.get(input, :action) || Map.get(input, "action")
    do_handle(action, input)
  end

  defp do_handle("create", input) do
    address = Map.get(input, :address) || Map.get(input, "address")
    ttl = Map.get(input, :ttl_seconds) || Map.get(input, "ttl_seconds") || 3600
    
    expires_at = System.system_time(:second) + ttl
    
    secret = Lux.Integrations.Web3Auth.session_secret()
    payload = %{"address" => address, "exp" => expires_at}
    # Hand-rolled JWT-like token to avoid external dependencies
    payload_json = Jason.encode!(payload)
    encoded_payload = Base.url_encode64(payload_json, padding: false)
    
    signature = :crypto.mac(:hmac, :sha256, secret, encoded_payload) |> Base.url_encode64(padding: false)
    token = "#{encoded_payload}.#{signature}"
    
    {:ok, %{token: token, expires_at: expires_at, address: address}}
  end

  defp do_handle("validate", input) do
    token = Map.get(input, :token) || Map.get(input, "token")
    secret = Lux.Integrations.Web3Auth.session_secret()
    
    case String.split(token, ".") do
      [encoded_payload, signature] ->
        expected_sig = :crypto.mac(:hmac, :sha256, secret, encoded_payload) |> Base.url_encode64(padding: false)
        if expected_sig == signature do
          case Base.url_decode64(encoded_payload, padding: false) do
            {:ok, json} ->
              payload = Jason.decode!(json)
              expires_at = Map.get(payload, "exp")
              address = Map.get(payload, "address")
              
              if System.system_time(:second) < expires_at do
                {:ok, %{valid: true, address: address, expires_at: expires_at}}
              else
                {:ok, %{valid: false, error: "Session expired"}}
              end
            :error ->
              {:ok, %{valid: false, error: "Malformed payload"}}
          end
        else
          {:ok, %{valid: false, error: "Invalid signature"}}
        end
      _ ->
        {:ok, %{valid: false, error: "Malformed token"}}
    end
  end
  
  defp do_handle(_, _) do
    {:error, "Invalid action or parameters"}
  end
end
