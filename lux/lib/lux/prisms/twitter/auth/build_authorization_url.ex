defmodule Lux.Prisms.Twitter.Auth.BuildAuthorizationUrl do
  @moduledoc "Builds an OAuth 2.0 PKCE authorization URL for X/Twitter."

  use Lux.Prism,
    name: "Build Twitter OAuth URL",
    description: "Builds an X/Twitter OAuth 2.0 PKCE authorization URL",
    input_schema: %{
      type: :object,
      properties: %{
        client_id: %{type: :string},
        redirect_uri: %{type: :string},
        state: %{type: :string},
        code_verifier: %{type: :string},
        scopes: %{type: :array, items: %{type: :string}}
      },
      required: ["client_id", "redirect_uri", "state"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(input, _context) do
    pkce = Client.pkce_pair(input[:code_verifier])
    url = Client.authorization_url(Map.put(input, :code_verifier, pkce.verifier))

    {:ok, %{authorization_url: url, code_verifier: pkce.verifier, code_challenge: pkce.challenge}}
  end
end
