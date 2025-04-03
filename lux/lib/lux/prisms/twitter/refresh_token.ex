defmodule Lux.Prisms.Twitter.RefreshToken do
  @moduledoc """
  A prism for refreshing Twitter API access tokens.

  This prism provides agents with the ability to refresh their Twitter API access tokens
  when they encounter authorization errors. The prism leverages the Twitter authentication
  module and follows best practices by:

  - Allowing agents to explicitly refresh tokens when needed
  - Supporting custom credentials for multi-account scenarios
  - Providing clear success/failure responses with token details
  - Preserving error information for LLM interpretation

  ## Implementation Details

  - Uses Twitter API v2 OAuth2 token endpoint
  - Returns a response with token information on success
  - Preserves original Twitter API errors for better error handling by LLMs
  - Tokens are cached automatically to avoid unnecessary refreshes

  ## Examples

      # Refresh token using default credentials from config
      iex> RefreshToken.handler(%{}, %{name: "Agent"})
      {:ok, %{success: true, message: "Token refreshed successfully"}}

      # Refresh with custom credentials
      iex> RefreshToken.handler(%{
      ...>   client_id: "custom_client_id",
      ...>   client_secret: "custom_client_secret",
      ...>   refresh_token: "custom_refresh_token"
      ...> }, %{name: "Agent"})
      {:ok, %{success: true, message: "Token refreshed successfully"}}
  """

  use Lux.Prism,
    name: "Refresh Twitter Token",
    description: "Refreshes the Twitter API access token",
    input_schema: %{
      type: :object,
      properties: %{
        client_id: %{
          type: :string,
          description: "Optional Twitter API client ID. Defaults to config value if not provided."
        },
        client_secret: %{
          type: :string,
          description: "Optional Twitter API client secret. Defaults to config value if not provided."
        },
        refresh_token: %{
          type: :string,
          description: "Optional OAuth refresh token. Defaults to config value if not provided."
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether the token refresh was successful"
        },
        message: %{
          type: :string,
          description: "A descriptive message about the result"
        }
      },
      required: ["success", "message"]
    }

  alias Lux.Integrations.Twitter
  require Logger

  @doc """
  Handles the request to refresh a Twitter access token.

  This implementation:
  - Takes optional custom credentials
  - Falls back to config values when not provided
  - Returns success/failure responses with relevant information
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} refreshing Twitter token")

    # Extract optional parameters
    opts = [
      client_id: Map.get(params, :client_id),
      client_secret: Map.get(params, :client_secret),
      refresh_token: Map.get(params, :refresh_token)
    ]
    # Remove nil values
    opts = Enum.reject(opts, fn {_k, v} -> is_nil(v) end)

    case Twitter.refresh_access_token(opts) do
      {:ok, _token} ->
        Logger.info("Successfully refreshed Twitter token for #{agent_name}")
        {:ok, %{success: true, message: "Token refreshed successfully"}}

      error -> handle_refresh_error(error)
    end
  end

  defp handle_refresh_error({:error, :missing_credentials}) do
    error_message = "Twitter OAuth credentials missing. Please check your configuration."
    Logger.error(error_message)
    {:error, %{success: false, message: error_message}}
  end

  defp handle_refresh_error({:error, {status, %{"detail" => detail}}}) do
    error_message = "Token refresh failed (#{status}): #{detail}"
    Logger.error(error_message)
    {:error, %{success: false, message: error_message}}
  end

  defp handle_refresh_error({:error, {status, body}}) do
    error_message = "Token refresh failed (#{status}): #{inspect(body)}"
    Logger.error(error_message)
    {:error, %{success: false, message: error_message}}
  end

  defp handle_refresh_error({:error, error}) do
    error_message = "Token refresh failed: #{inspect(error)}"
    Logger.error(error_message)
    {:error, %{success: false, message: error_message}}
  end
end
