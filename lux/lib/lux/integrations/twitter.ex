defmodule Lux.Integrations.Twitter do
  @moduledoc """
  Common settings and functions for Twitter API integration.
  """

  require Logger

  @doc """
  Common request settings for Twitter API calls.
  """
  def request_settings do
    %{
      headers: [{"Content-Type", "application/json"}],
      auth: %{
        type: :custom,
        auth_function: &__MODULE__.add_auth_header/1
      }
    }
  end

  @doc """
  Common headers for Twitter API calls.
  """
  def headers, do: [{"Content-Type", "application/json"}]

  @doc """
  Common auth settings for Twitter API calls.
  """
  def auth, do: %{
    type: :custom,
    auth_function: &__MODULE__.add_auth_header/1
  }

  @doc """
  Adds Twitter OAuth2 bearer token authorization header.
  """
  @spec add_auth_header(Lux.Lens.t()) :: Lux.Lens.t()
  def add_auth_header(%Lux.Lens{} = lens) do
    case get_access_token() do
      {:ok, token} ->
        %{lens | headers: lens.headers ++ [{"Authorization", "Bearer #{token}"}]}
      {:error, reason} ->
        Logger.error("Failed to get Twitter access token: #{inspect(reason)}")
        lens
    end
  end

  @spec add_auth_header(Plug.Conn.t()) :: Plug.Conn.t()
  def add_auth_header(%Plug.Conn{} = conn) do
    case get_access_token() do
      {:ok, token} ->
        Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
      {:error, reason} ->
        Logger.error("Failed to get Twitter access token: #{inspect(reason)}")
        conn
    end
  end

  @doc """
  Gets a valid access token using the refresh token.
  Uses caching to avoid refreshing the token on every request.
  """
  def get_access_token do
    # For testing, return a test token if configured
    case Application.get_env(:lux, :twitter_test_token) do
      nil ->
        # Check if we have a cached token that's still valid
        now = current_time_seconds()
        case get_cached_token() do
          {:ok, token, expiry} when expiry > now + 60 ->
            {:ok, token}
          _ ->
            refresh_access_token()
        end
      test_token ->
        {:ok, test_token} # Return the test token for testing
    end
  end

  @doc """
  Refreshes the Twitter access token using the stored refresh token.
  """
  def refresh_access_token do
    client_id = Lux.Config.twitter_client_id()
    client_secret = Lux.Config.twitter_client_secret()
    refresh_token = Lux.Config.twitter_oauth_refresh_token()

    # Check if all credentials are present
    credentials_present = client_id && client_secret && refresh_token

    if credentials_present do
      auth_header = "Basic " <> Base.encode64("#{client_id}:#{client_secret}")

      case Req.post("https://api.twitter.com/2/oauth2/token",
        headers: [
          {"Authorization", auth_header},
          {"Content-Type", "application/x-www-form-urlencoded"}
        ],
        form: [
          grant_type: "refresh_token",
          refresh_token: refresh_token
        ]
      ) do
        {:ok, %{status: 200, body: body}} ->
          token = body["access_token"]
          expires_in = body["expires_in"]

          # Cache the token with its expiration time
          cache_token(token, expires_in)

          {:ok, token}
        {:ok, %{status: status, body: body}} ->
          Logger.error("Twitter token refresh failed with status #{status}: #{inspect(body)}")
          {:error, {status, body}}
        {:error, error} ->
          Logger.error("Twitter token refresh request failed: #{inspect(error)}")
          {:error, error}
      end
    else
      Logger.error("Twitter OAuth credentials missing")
      {:error, :missing_credentials}
    end
  end

  # Token caching functions
  defp cache_token(token, expires_in) do
    expiry = current_time_seconds() + expires_in
    :persistent_term.put({__MODULE__, :twitter_token}, {token, expiry})
  end

  defp get_cached_token do
    case :persistent_term.get({__MODULE__, :twitter_token}, :not_found) do
      :not_found -> {:error, :no_cached_token}
      {token, expiry} -> {:ok, token, expiry}
    end
  end

  defp current_time_seconds do
    DateTime.utc_now() |> DateTime.to_unix()
  end
end
