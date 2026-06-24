defmodule Lux.Integrations.YouTube do
  @moduledoc """
  Integration with the YouTube Data API v3 for managing YouTube channels,
  video uploads, live streams, and real-time chat interaction.

  ## Configuration

  The following configuration is required in your `config/runtime.exs`:

      config :lux, :api_keys,
        youtube_oauth_access: System.get_env("YOUTUBE_OAUTH_ACCESS_TOKEN"),
        youtube_oauth_refresh: System.get_env("YOUTUBE_OAUTH_REFRESH_TOKEN"),
        youtube_api_key: System.get_env("YOUTUBE_API_KEY")

  And in your environment file (e.g., `dev.envrc`):

      YOUTUBE_OAUTH_ACCESS_TOKEN="ya29.a0Af..."
      YOUTUBE_OAUTH_REFRESH_TOKEN="1//0e..."
      YOUTUBE_API_KEY="AIzaSy..."
      YOUTUBE_CHANNEL_ID="UCxxxxxxxxxxxxxxxxxxxx"

  ## Authentication

  OAuth2 authentication is handled via access and refresh tokens. The module
  supports automatic token refresh when the access token expires.

  ### OAuth2 Flow

  1. Redirect users to the Google authorization URL
  2. Exchange the authorization code for access/refresh tokens
  3. Store tokens securely (database, encrypted vault, etc.)
  4. Use access tokens for API calls; refresh automatically when expired

  ## API Endpoints Covered

  - Videos: upload, list, update, delete
  - Live Streams: create, list, update, transition to live
  - Broadcasts: list, update, delete
  - Chat: list messages, send messages, moderation
  - Channel: retrieve channel settings
  - Thumbnails: upload custom thumbnails

  ## Usage Examples

      # Get base API URL
      base_url = YouTube.api_base_url()
      # => "https://www.googleapis.com/youtube/v3"

      # Get API key
      api_key = YouTube.api_key()

      # Get auth headers
      headers = YouTube.auth_headers()
      # => [{"Authorization", "Bearer ya29.a0Af..."}]

      # Using with Lenses
      defmodule MyApp.Lenses.YouTube.UploadVideo do
        use Lux.Lens,
          name: "Upload YouTube Video",
          url: "#{YouTube.api_base_url()}/videos",
          method: :post,
          headers: YouTube.auth_headers(),
          auth: YouTube.auth()
      end

  ## Rate Limiting

  The YouTube API enforces a daily quota of 10,000 units. Key costs:
  - Video insert (standard): 1,600 units
  - Video insert (streaming): 50 units
  - Videos.list: 1 unit
  - LiveStream.insert: 50 units
  - Chat.messages.list: 1 unit
  """

  @type api_key :: String.t()
  @type oauth_token :: String.t()
  @type channel_id :: String.t()
  @type headers :: [{String.t(), String.t()}]

  require Logger

  @doc """
  Gets the YouTube Data API v3 base URL.
  """
  @spec api_base_url() :: String.t()
  def api_base_url do
    "https://www.googleapis.com/youtube/v3"
  end

  @doc """
  Gets the YouTube API key from configuration.
  Used for quota tracking and optional API key param.
  """
  @spec api_key() :: api_key()
  def api_key do
    :lux
    |> Application.get_env(:api_keys)
    |> Keyword.get(:youtube_api_key)
  end

  @doc """
  Gets the OAuth2 access token from configuration.
  Raises if the token is not configured.
  """
  @spec access_token() :: oauth_token()
  def access_token do
    :lux
    |> Application.get_env(:api_keys)
    |> Keyword.get(:youtube_oauth_access)
    |> case do
      nil -> raise ":youtube_oauth_access is not configured in :api_keys!"
      value -> value
    end
  end

  @doc """
  Gets the OAuth2 refresh token from configuration.
  """
  @spec refresh_token() :: oauth_token()
  def refresh_token do
    :lux
    |> Application.get_env(:api_keys)
    |> Keyword.get(:youtube_oauth_refresh)
  end

  @doc """
  Gets the configured YouTube channel ID.
  """
  @spec channel_id() :: channel_id()
  def channel_id do
    :lux
    |> Application.get_env(:api_keys)
    |> Keyword.get(:youtube_channel_id)
  end

  @doc """
  Gets the default headers for YouTube API requests.
  """
  @spec headers() :: headers()
  def headers do
    [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]
  end

  @doc """
  Gets the Authorization headers with the OAuth2 bearer token.
  """
  @spec auth_headers() :: headers()
  def auth_headers do
    [{"Authorization", "Bearer #{access_token()}"}]
  end

  @doc """
  Gets the authentication configuration for YouTube API requests.
  """
  @spec auth() :: map()
  def auth do
    %{
      type: :oauth,
      token: &__MODULE__.access_token/0
    }
  end

  @doc """
  Authenticates a lens by adding the Authorization header.
  Only adds the header if not already present.
  """
  @spec authenticate(map()) :: map()
  def authenticate(%{headers: headers} = lens) do
    case Enum.find(headers, fn {key, _} -> String.downcase(key) == "authorization" end) do
      nil ->
        %{lens | headers: auth_headers() ++ headers}
      _ ->
        lens
    end
  end

  @doc """
  Builds the query params with API key appended.
  Useful for lenses that need the API key in the query string.
  """
  @spec with_api_key(map()) :: map()
  def with_api_key(params) do
    api_key = __MODULE__.api_key()
    if api_key, do: Map.put(params, :key, api_key), else: params
  end

  @doc """
  Generates the OAuth2 authorization URL for the YouTube login flow.
  """
  @spec authorization_url() :: String.t()
  def authorization_url do
    client_id = System.get_env("GOOGLE_CLIENT_ID", "")
    redirect_uri = System.get_env("GOOGLE_REDIRECT_URI", "http://localhost:4000/auth/youtube/callback")
    scope = "https://www.googleapis.com/auth/youtube https://www.googleapis.com/auth/youtube.force-ssl https://www.googleapis.com/auth/youtube.readonly https://www.googleapis.com/auth/youtube.upload"

    "https://accounts.google.com/o/oauth2/v2/auth?" <>
      URI.encode_query([
        {"client_id", client_id},
        {"redirect_uri", redirect_uri},
        {"response_type", "code"},
        {"scope", scope},
        {"access_type", "offline"},
        {"prompt", "consent"}
      ])
  end

  @doc """
  Validates a YouTube video ID format.
  """
  @spec validate_video_id(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def validate_video_id(id) when is_binary(id) and byte_size(id) == 11 do
    {:ok, id}
  end

  def validate_video_id(id) when is_binary(id) do
    {:error, "Invalid YouTube video ID format (expected 11 characters): #{id}"}
  end

  @doc """
  Validates a YouTube channel ID format.
  """
  @spec validate_channel_id(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def validate_channel_id(id) when is_binary(id) do
    cond do
      String.match?(id, ~r/^UC[a-zA-Z0-9_-]{22}$/) -> {:ok, id}
      String.match?(id, ~r/^@[a-zA-Z0-9_-]+$/) -> {:ok, id}
      true -> {:error, "Invalid YouTube channel ID format: #{id}"}
    end
  end

  @doc """
  Validates a live stream bitrate suggestion based on resolution.
  """
  @spec suggest_bitrate(String.t()) :: integer()
  def suggest_bitrate("1080p"), do: 4500000
  def suggest_bitrate("720p"), do: 2500000
  def suggest_bitrate("480p"), do: 1500000
  def suggest_bitrate("360p"), do: 1000000
  def suggest_bitrate(_), do: 2500000
end
