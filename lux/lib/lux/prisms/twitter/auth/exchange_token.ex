defmodule Lux.Prisms.Twitter.Auth.ExchangeToken do
  @moduledoc "Exchanges an authorization code or refresh token for X/Twitter OAuth tokens."

  use Lux.Prism,
    name: "Exchange Twitter OAuth Token",
    description: "Exchanges an X/Twitter OAuth code or refresh token",
    input_schema: %{
      type: :object,
      properties: %{
        grant_type: %{type: :string, enum: ["authorization_code", "refresh_token"]},
        client_id: %{type: :string},
        client_secret: %{type: :string},
        redirect_uri: %{type: :string},
        code: %{type: :string},
        code_verifier: %{type: :string},
        refresh_token: %{type: :string}
      },
      required: ["grant_type", "client_id"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(%{grant_type: grant_type} = input, _context) do
    case normalize_grant_type(grant_type) do
      {:ok, grant_type} -> Client.token_request(grant_type, Map.delete(input, :grant_type))
      {:error, reason} -> {:error, reason}
    end
  end

  def handler(_input, _context), do: {:error, "Missing grant_type"}

  defp normalize_grant_type(value) when value in [:authorization_code, :refresh_token],
    do: {:ok, value}

  defp normalize_grant_type("authorization_code"), do: {:ok, :authorization_code}
  defp normalize_grant_type("refresh_token"), do: {:ok, :refresh_token}
  defp normalize_grant_type(value), do: {:error, {:unsupported_grant_type, value}}
end
