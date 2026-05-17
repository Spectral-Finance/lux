defmodule Lux.Prisms.YouTube.OAuth.ExchangeCode do
  @moduledoc """
  Exchanges a YouTube OAuth authorization code for access and refresh tokens.
  """

  use Lux.Prism,
    name: "Exchange YouTube OAuth Code",
    description: "Exchanges an OAuth2 authorization code for YouTube access and refresh tokens",
    input_schema: %{
      type: :object,
      properties: %{
        code: %{type: :string, description: "Authorization code returned by Google OAuth"},
        redirect_uri: %{type: :string, description: "Redirect URI used for the consent request"},
        code_verifier: %{type: :string, description: "PKCE code verifier, when PKCE was used"},
        client_id: %{type: :string, description: "OAuth client id override"},
        client_secret: %{type: :string, description: "OAuth client secret override"}
      },
      required: ["code", "redirect_uri"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        access_token: %{type: :string},
        refresh_token: %{type: :string},
        expires_in: %{type: :integer},
        token_type: %{type: :string},
        scope: %{type: :string}
      },
      required: ["access_token"]
    }

  alias Lux.Integrations.YouTube.Client

  def handler(params, _agent) do
    with {:ok, code} <- required(params, :code),
         {:ok, redirect_uri} <- required(params, :redirect_uri) do
      form =
        %{
          grant_type: "authorization_code",
          code: code,
          redirect_uri: redirect_uri,
          client_id: params[:client_id] || Lux.Config.youtube_client_id(),
          client_secret: params[:client_secret] || Lux.Config.youtube_client_secret(),
          code_verifier: params[:code_verifier]
        }
        |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
        |> Map.new()

      case Client.request(:post, "", base: :oauth, auth: false, form: form, plug: params[:plug]) do
        {:ok, response} -> {:ok, normalize_token_response(response)}
        {:error, error} -> {:error, error}
      end
    end
  end

  defp normalize_token_response(response) do
    %{
      access_token: response["access_token"],
      refresh_token: response["refresh_token"],
      expires_in: response["expires_in"],
      token_type: response["token_type"],
      scope: response["scope"]
    }
  end

  defp required(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
