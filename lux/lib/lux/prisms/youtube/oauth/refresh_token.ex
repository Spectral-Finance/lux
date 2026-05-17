defmodule Lux.Prisms.YouTube.OAuth.RefreshToken do
  @moduledoc """
  Refreshes a YouTube OAuth access token.
  """

  use Lux.Prism,
    name: "Refresh YouTube OAuth Token",
    description: "Uses a YouTube OAuth refresh token to obtain a new access token",
    input_schema: %{
      type: :object,
      properties: %{
        refresh_token: %{type: :string, description: "OAuth refresh token"},
        client_id: %{type: :string, description: "OAuth client id override"},
        client_secret: %{type: :string, description: "OAuth client secret override"}
      },
      required: ["refresh_token"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        access_token: %{type: :string},
        expires_in: %{type: :integer},
        token_type: %{type: :string},
        scope: %{type: :string}
      },
      required: ["access_token"]
    }

  alias Lux.Integrations.YouTube.Client

  def handler(params, _agent) do
    with {:ok, refresh_token} <- required(params, :refresh_token) do
      form = %{
        grant_type: "refresh_token",
        refresh_token: refresh_token,
        client_id: params[:client_id] || Lux.Config.youtube_client_id(),
        client_secret: params[:client_secret] || Lux.Config.youtube_client_secret()
      }

      case Client.request(:post, "", base: :oauth, auth: false, form: form, plug: params[:plug]) do
        {:ok, response} -> {:ok, normalize_token_response(response)}
        {:error, error} -> {:error, error}
      end
    end
  end

  defp normalize_token_response(response) do
    %{
      access_token: response["access_token"],
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
