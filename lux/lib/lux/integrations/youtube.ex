defmodule Lux.Integrations.YouTube do
  @moduledoc """
  Integration with the YouTube Data API v3 for accessing channel statistics,
  video analytics, search trends, and competitive analysis.

  The YouTube Data API provides programmatic access to YouTube data including:
  - Channel statistics (subscribers, views, video count)
  - Video performance metrics (views, likes, comments, retention)
  - Search and trending content discovery
  - Competitive channel analysis
  - Revenue estimation based on view data

  ## Configuration

  The following configuration is required in your `config/runtime.exs`:

      config :lux, Lux.Integrations.YouTube,
        api_key: System.get_env("YOUTUBE_API_KEY"),
        base_url: System.get_env("YOUTUBE_BASE_URL") || "https://www.googleapis.com/youtube/v3"

  And in your environment file (e.g., `dev.envrc` or `test.envrc`):

      YOUTUBE_API_KEY="your-youtube-api-key"
      YOUTUBE_BASE_URL="https://www.googleapis.com/youtube/v3"  # Optional, defaults to this value

  ## Authentication

  Authentication is handled via API key passed as a query parameter (`key`).
  The key is fetched from the application configuration and added to each request.

  ## API Endpoints

  The integration supports the following YouTube Data API v3 endpoints:

  - **Channels**: `https://www.googleapis.com/youtube/v3/channels`
  - **Videos**: `https://www.googleapis.com/youtube/v3/videos`
  - **Search**: `https://www.googleapis.com/youtube/v3/search`
  - **Analytics**: `https://www.googleapis.com/youtubeAnalytics/v2/reports`

  ## Usage Examples

  ### Basic Setup

      # In your lens or module:
      alias Lux.Integrations.YouTube

      # Get configured base URL
      base_url = YouTube.base_url()
      # => "https://www.googleapis.com/youtube/v3"

      # Get authentication headers
      headers = YouTube.headers()
      # => [{"content-type", "application/json"}, {"accept", "application/json"}]

      # Get authentication config
      auth = YouTube.auth()
      # => %{type: :api_key, key: &Lux.Integrations.YouTube.api_key/0}

  ### Using with Lenses

      defmodule MyApp.Lenses.YouTubeExample do
        use Lux.Lens,
          name: "YouTube Example",
          url: "#{YouTube.base_url()}/channels",
          method: :get,
          headers: YouTube.headers(),
          auth: YouTube.auth()
      end

  ### Error Handling

  The module includes robust error handling for common scenarios:

      # API key validation
      YouTube.api_key()  # Raises if YOUTUBE_API_KEY is not configured

      # Authentication
      auth = YouTube.auth()  # Returns auth configuration

  ## Available Lenses

  The integration includes five main lenses:

  1. `Lux.Lenses.YouTube.ChannelStatsLens` - Fetches channel statistics
     ```elixir
     {:ok, stats} = Lux.Lenses.YouTube.ChannelStatsLens.focus(%{
       channel_id: "UC_x5XG1OV2P6uZZ5FSM9Ttw"  # Google Developers
     })
     # Returns subscriber count, view count, video count, etc.
     ```

  2. `Lux.Lenses.YouTube.VideoAnalyticsLens` - Fetches video performance metrics
     ```elixir
     {:ok, analytics} = Lux.Lenses.YouTube.VideoAnalyticsLens.focus(%{
       video_id: "dQw4w9WgXcQ",
       start_date: "2024-01-01",
       end_date: "2024-01-31"
     })
     # Returns views, likes, comments, estimated revenue, etc.
     ```

  3. `Lux.Lenses.YouTube.SearchTrendsLens` - Searches for trending content
     ```elixir
     {:ok, results} = Lux.Lenses.YouTube.SearchTrendsLens.focus(%{
       query: "elixir programming",
       max_results: 10,
       order: "relevance"
     })
     # Returns list of trending videos matching the query
     ```

  4. `Lux.Lenses.YouTube.CompetitorAnalysisLens` - Compares multiple channels
     ```elixir
     {:ok, comparison} = Lux.Lenses.YouTube.CompetitorAnalysisLens.focus(%{
       channel_ids: ["UC_CHANNEL_1", "UC_CHANNEL_2"],
       metrics: ["subscriberCount", "viewCount", "videoCount"]
     })
     # Returns comparative data across channels
     ```

  5. `Lux.Lenses.YouTube.RevenueEstimatorLens` - Estimates YouTube revenue
     ```elixir
     {:ok, estimate} = Lux.Lenses.YouTube.RevenueEstimatorLens.focus(%{
       channel_id: "UC_x5XG1OV2P6uZZ5FSM9Ttw",
       cpm_range: {2.0, 5.0}
     })
     # Returns estimated revenue ranges based on views and CPM
     ```

  ## Response Formats

  ### Channel Statistics Response
      %{
        channel_id: "UC_x5XG1OV2P6uZZ5FSM9Ttw",
        title: "Google Developers",
        description: "...",
        statistics: %{
          subscriber_count: 2_500_000,
          view_count: 150_000_000,
          video_count: 1_200,
          hidden_subscriber_count: false
        },
        thumbnails: %{
          default: "https://...",
          medium: "https://...",
          high: "https://..."
        }
      }

  ### Video Analytics Response
      %{
        video_id: "dQw4w9WgXcQ",
        title: "...",
        published_at: "2024-01-15T12:00:00Z",
        statistics: %{
          view_count: 1_000_000,
          like_count: 50_000,
          comment_count: 10_000,
          favorite_count: 5_000
        },
        engagement_rate: 0.055,
        analytics: %{
          estimated_minutes_watched: 250_000,
          average_view_duration: 15.0,
          viewer_percentage: 65.5
        }
      }

  ### Search Results Response
      %{
        results: [
          %{
            video_id: "abc123",
            title: "...",
            description: "...",
            channel_id: "UC_...",
            channel_title: "...",
            published_at: "2024-01-15T12:00:00Z",
            thumbnails: %{...}
          }
        ],
        next_page_token: "...",
        total_results: 1000
      }

  ## Rate Limits

  The YouTube Data API v3 has quota-based rate limiting. Each API call
  consumes a certain number of quota units:

  - `channels.list`: 1 unit
  - `videos.list`: 1 unit
  - `search.list`: 100 units
  - `youtubeAnalytics.reports.query`: 50 units

  Default daily quota: 10,000 units

  For more information, see: https://developers.google.com/youtube/v3/getting-started#quota
  """

  @type auth_type :: :api_key
  @type api_key :: String.t()
  @type headers :: [{String.t(), String.t()}]
  @type base_url :: String.t()

  require Logger

  @doc """
  Gets the configured YouTube API base URL.
  Defaults to "https://www.googleapis.com/youtube/v3" if not configured.
  """
  @spec base_url() :: base_url()
  def base_url do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:base_url, "https://www.googleapis.com/youtube/v3")
  end

  @doc """
  Gets the configured YouTube Analytics API base URL.
  Defaults to "https://www.googleapis.com/youtubeAnalytics/v2" if not configured.
  """
  @spec analytics_base_url() :: base_url()
  def analytics_base_url do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:analytics_base_url, "https://www.googleapis.com/youtubeAnalytics/v2")
  end

  @doc """
  Gets the default headers for YouTube API requests.
  """
  @spec headers() :: headers()
  def headers do
    [
      {"content-type", "application/json"},
      {"accept", "application/json"}
    ]
  end

  @doc """
  Gets the authentication configuration for YouTube API requests.
  Uses API key-based authentication.
  """
  @spec auth() :: map()
  def auth do
    %{
      type: :api_key,
      key: &__MODULE__.api_key/0
    }
  end

  @doc """
  Adds the YouTube API key to a lens configuration.
  Appends the API key to the lens parameters.

  ## Parameters
    - `lens`: The lens struct to add the API key to

  ## Returns
    - Updated lens with API key in params
  """
  @spec add_api_key(map()) :: map()
  def add_api_key(lens) do
    api_key = api_key()
    params = Map.put(lens.params, :key, api_key)
    %{lens | params: params}
  end

  @doc """
  Gets the YouTube API key from configuration.
  Returns nil if not configured (use `api_key!` for required keys).
  """
  @spec api_key() :: api_key() | nil
  def api_key do
    :lux
    |> Application.get_env(__MODULE__)
    |> Keyword.get(:api_key)
  end

  @doc """
  Gets the YouTube API key from configuration.
  Raises if the key is not configured.
  """
  @spec api_key!() :: api_key()
  def api_key! do
    case api_key() do
      nil ->
        raise "YouTube API key is not configured. Set YOUTUBE_API_KEY in your environment."

      key ->
        key
    end
  end

  @doc """
  Formats a date string for YouTube Analytics API.
  Accepts Date, NaiveDateTime, DateTime, or string in ISO 8601 format.

  ## Parameters
    - `date`: The date to format

  ## Returns
    - String in "YYYY-MM-DD" format

  ## Examples

      iex> format_date(~D[2024-01-15])
      "2024-01-15"

      iex> format_date("2024-01-15")
      "2024-01-15"
  """
  @spec format_date(Date.t() | NaiveDateTime.t() | DateTime.t() | String.t()) :: String.t()
  def format_date(%Date{} = date), do: Date.to_string(date)

  def format_date(%NaiveDateTime{} = datetime), do: NaiveDateTime.to_date(datetime) |> Date.to_string()

  def format_date(%DateTime{} = datetime), do: DateTime.to_date(datetime) |> Date.to_string()

  def format_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> Date.to_string(date)
      {:error, _reason} -> date_string
    end
  end

  @doc """
  Validates a YouTube channel ID format.
  Channel IDs typically start with "UC" followed by 22 characters.

  ## Parameters
    - `channel_id`: The channel ID to validate

  ## Returns
    - `{:ok, channel_id}` if valid
    - `{:error, reason}` if invalid

  ## Examples

      iex> validate_channel_id("UC_x5XG1OV2P6uZZ5FSM9Ttw")
      {:ok, "UC_x5XG1OV2P6uZZ5FSM9Ttw"}

      iex> validate_channel_id("invalid")
      {:error, "Invalid YouTube channel ID format"}
  """
  @spec validate_channel_id(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def validate_channel_id("UC" <> _rest = channel_id) when byte_size(channel_id) == 24 do
    {:ok, channel_id}
  end

  def validate_channel_id(channel_id) when is_binary(channel_id) do
    {:error, "Invalid YouTube channel ID format. Expected format: UC followed by 22 characters"}
  end

  @doc """
  Validates a YouTube video ID format.
  Video IDs are typically 11 characters long.

  ## Parameters
    - `video_id`: The video ID to validate

  ## Returns
    - `{:ok, video_id}` if valid
    - `{:error, reason}` if invalid

  ## Examples

      iex> validate_video_id("dQw4w9WgXcQ")
      {:ok, "dQw4w9WgXcQ"}

      iex> validate_video_id("invalid")
      {:error, "Invalid YouTube video ID format"}
  """
  @spec validate_video_id(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def validate_video_id(video_id) when byte_size(video_id) == 11 do
    {:ok, video_id}
  end

  def validate_video_id(video_id) when is_binary(video_id) do
    {:error, "Invalid YouTube video ID format. Expected 11 characters"}
  end
end
