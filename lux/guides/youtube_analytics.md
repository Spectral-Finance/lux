# YouTube Analytics and Growth Engine

A comprehensive integration for the Spectral Finance Lux framework that provides programmatic access to YouTube Data API v3 for channel analytics, video performance tracking, trend discovery, competitive analysis, and revenue estimation.

## Table of Contents

- [Installation](#installation)
- [Configuration](#configuration)
- [Available Lenses](#available-lenses)
  - [ChannelStatsLens](#channelstatslens)
  - [VideoAnalyticsLens](#videoanalyticslens)
  - [SearchTrendsLens](#searchtrendslens)
  - [CompetitorAnalysisLens](#competitoranalysislens)
  - [RevenueEstimatorLens](#revenueestimatorlens)
- [Integration Module](#integration-module)
- [Usage Examples](#usage-examples)
- [Error Handling](#error-handling)
- [Rate Limits and Quotas](#rate-limits-and-quotas)
- [Best Practices](#best-practices)

## Installation

The YouTube Analytics integration is part of the Lux framework. No additional dependencies are required beyond the standard Lux setup.

### Prerequisites

1. A Google Cloud Platform account
2. A project with the YouTube Data API v3 enabled
3. An API key for the YouTube Data API

## Configuration

### 1. Enable YouTube Data API v3

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select or create a project
3. Navigate to **APIs & Services > Library**
4. Search for "YouTube Data API v3" and enable it
5. Go to **APIs & Services > Credentials**
6. Create an API key (or use an existing one)

### 2. Configure Lux

Add the YouTube configuration to your `config/runtime.exs`:

```elixir
config :lux, Lux.Integrations.YouTube,
  api_key: System.get_env("YOUTUBE_API_KEY"),
  base_url: System.get_env("YOUTUBE_BASE_URL") || "https://www.googleapis.com/youtube/v3",
  analytics_base_url: System.get_env("YOUTUBE_ANALYTICS_BASE_URL") || "https://www.googleapis.com/youtubeAnalytics/v2"
```

Add the API key to your environment file (e.g., `dev.envrc`):

```bash
YOUTUBE_API_KEY="your-youtube-api-key-here"
```

### 3. Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `YOUTUBE_API_KEY` | YouTube Data API v3 key | Yes | - |
| `YOUTUBE_BASE_URL` | Base URL for YouTube Data API | No | `https://www.googleapis.com/youtube/v3` |
| `YOUTUBE_ANALYTICS_BASE_URL` | Base URL for YouTube Analytics API | No | `https://www.googleapis.com/youtubeAnalytics/v2` |

## Available Lenses

### ChannelStatsLens

Fetches comprehensive channel statistics including subscriber count, total views, video count, and channel metadata.

**Endpoint:** `GET https://www.googleapis.com/youtube/v3/channels`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `channel_id` | string | Yes* | YouTube channel ID(s), comma-separated (max 50) |
| `for_username` | string | Yes* | YouTube username (alternative to channel_id) |
| `for_handle` | string | Yes* | YouTube handle (e.g., @googledevelopers) |
| `part` | string | No | API parts to include. Default: `snippet,statistics` |

*One of `channel_id`, `for_username`, or `for_handle` is required.

**Example:**

```elixir
alias Lux.Lenses.YouTube.ChannelStatsLens

# Fetch stats for a single channel
{:ok, stats} = ChannelStatsLens.focus(%{
  channel_id: "UC_x5XG1OV2P6uZZ5FSM9Ttw"
})

IO.puts("Channel: #{stats.title}")
IO.puts("Subscribers: #{stats.statistics.subscriber_count}")
IO.puts("Total Views: #{stats.statistics.view_count}")
IO.puts("Videos: #{stats.statistics.video_count}")
```

**Response Format:**

```elixir
%{
  channel_id: "UC_x5XG1OV2P6uZZ5FSM9Ttw",
  title: "Google Developers",
  description: "Official Google Developers channel...",
  custom_url: "@googledevelopers",
  published_at: "2007-01-01T00:00:00Z",
  thumbnails: %{
    default: "https://...",
    medium: "https://...",
    high: "https://..."
  },
  statistics: %{
    subscriber_count: 2_500_000,
    view_count: 150_000_000,
    video_count: 1_200,
    hidden_subscriber_count: false
  }
}
```

### VideoAnalyticsLens

Fetches video performance metrics including view counts, engagement metrics, and content details.

**Endpoint:** `GET https://www.googleapis.com/youtube/v3/videos`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `video_id` | string | Yes | YouTube video ID(s), comma-separated (max 50) |
| `part` | string | No | API parts to include. Default: `snippet,statistics,contentDetails` |
| `start_date` | string | No | Start date for analytics (ISO 8601) |
| `end_date` | string | No | End date for analytics (ISO 8601) |
| `metrics` | array | No | Analytics metrics to include |

**Example:**

```elixir
alias Lux.Lenses.YouTube.VideoAnalyticsLens

{:ok, analytics} = VideoAnalyticsLens.focus(%{
  video_id: "dQw4w9WgXcQ"
})

IO.puts("Title: #{analytics.title}")
IO.puts("Views: #{analytics.statistics.view_count}")
IO.puts("Likes: #{analytics.statistics.like_count}")
IO.puts("Engagement Rate: #{analytics.engagement_rate}%")
```

**Response Format:**

```elixir
%{
  video_id: "dQw4w9WgXcQ",
  title: "Video Title",
  description: "Video description...",
  published_at: "2024-01-15T12:00:00Z",
  channel_id: "UC_x5XG1OV2P6uZZ5FSM9Ttw",
  channel_title: "Channel Name",
  tags: ["tag1", "tag2"],
  thumbnails: %{
    default: "https://...",
    medium: "https://...",
    high: "https://...",
    standard: "https://...",
    maxres: "https://..."
  },
  content_details: %{
    duration: "PT3M33S",
    dimension: "2d",
    definition: "hd",
    caption: "true",
    licensed: true
  },
  statistics: %{
    view_count: 1_000_000,
    like_count: 50_000,
    dislike_count: 500,
    favorite_count: 5_000,
    comment_count: 10_000
  },
  engagement_rate: 0.06  # (likes + comments) / views * 100
}
```

### SearchTrendsLens

Searches YouTube for trending content, videos, and channels by query.

**Endpoint:** `GET https://www.googleapis.com/youtube/v3/search`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | string | Yes | Text query to search for |
| `max_results` | integer | No | Results to return (1-50). Default: 10 |
| `order` | string | No | Sort order. Options: `relevance`, `date`, `viewCount`, `rating`, `title` |
| `type` | string | No | Resource type. Options: `video`, `channel`, `playlist`, `movie` |
| `region_code` | string | No | ISO 3166-1 alpha-2 country code |
| `published_after` | string | No | Only videos published after this date |
| `published_before` | string | No | Only videos published before this date |
| `safe_search` | string | No | Filter level. Options: `moderate`, `strict`, `none` |
| `video_duration` | string | No | Filter by duration. Options: `short`, `medium`, `long` |
| `channel_id` | string | No | Restrict search to a specific channel |
| `page_token` | string | No | Token for pagination |

**Example:**

```elixir
alias Lux.Lenses.YouTube.SearchTrendsLens

# Search for trending Elixir content
{:ok, results} = SearchTrendsLens.focus(%{
  query: "elixir programming tutorial",
  max_results: 10,
  order: "relevance",
  type: "video"
})

Enum.each(results.results, fn video ->
  IO.puts("#{video.title} - #{video.channel_title}")
end)

# Paginate to next page
if results.next_page_token do
  {:ok, more_results} = SearchTrendsLens.focus(%{
    query: "elixir programming tutorial",
    page_token: results.next_page_token
  })
end
```

**Response Format:**

```elixir
%{
  results: [
    %{
      video_id: "abc123",
      title: "Video Title",
      description: "Video description...",
      channel_id: "UC_x5XG1OV2P6uZZ5FSM9Ttw",
      channel_title: "Channel Name",
      published_at: "2024-01-15T12:00:00Z",
      thumbnails: %{
        default: "https://...",
        medium: "https://...",
        high: "https://..."
      }
    }
  ],
  next_page_token: "CAUQAA",
  total_results: 1000,
  results_per_page: 10,
  region_code: "US"
}
```

### CompetitorAnalysisLens

Compares multiple YouTube channels for competitive analysis and benchmarking.

**Endpoint:** `GET https://www.googleapis.com/youtube/v3/channels`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `channel_ids` | array | Yes | List of channel IDs to compare (2-50) |
| `metrics` | array | No | Metrics to include. Default: subscriberCount, viewCount, videoCount, engagementRate |
| `include_rankings` | boolean | No | Include ranking scores. Default: true |
| `scoring_method` | string | No | Scoring method. Options: `weighted`, `simple`, `subscriber_focused`, `view_focused` |

**Example:**

```elixir
alias Lux.Lenses.YouTube.CompetitorAnalysisLens

{:ok, analysis} = CompetitorAnalysisLens.focus(%{
  channel_ids: [
    "UC_x5XG1OV2P6uZZ5FSM9Ttw",  # Google Developers
    "UCBR8-60-B28hp2BmDPdntcQ"   # YouTube Developers
  ],
  metrics: ["subscriberCount", "viewCount", "videoCount", "engagementRate"]
})

# View individual channel stats
Enum.each(analysis.channels, fn channel ->
  IO.puts("#{channel.title}: #{channel.statistics.subscriber_count} subscribers")
end)

# View comparison summary
IO.puts("Leader in subscribers: #{analysis.comparison.leader.subscribers}")
IO.puts("Leader in views: #{analysis.comparison.leader.views}")

# View rankings
Enum.each(analysis.comparison.rankings, fn ranking ->
  IO.puts("##{ranking.rank} - #{ranking.title} (score: #{ranking.score})")
end)
```

**Response Format:**

```elixir
%{
  channels: [
    %{
      channel_id: "UC_x5XG1OV2P6uZZ5FSM9Ttw",
      title: "Google Developers",
      description: "...",
      published_at: "2007-01-01T00:00:00Z",
      statistics: %{
        subscriber_count: 2_500_000,
        view_count: 150_000_000,
        video_count: 1_200,
        hidden_subscriber_count: false
      },
      avg_views_per_video: 125_000,
      engagement_rate: 0.017
    }
  ],
  comparison: %{
    total_subscribers: 5_000_000,
    total_views: 300_000_000,
    total_videos: 2_400,
    channel_count: 2,
    leader: %{
      subscribers: "Channel A",
      views: "Channel A",
      videos: "Channel B"
    },
    rankings: [
      %{channel_id: "UC_A", title: "Channel A", score: 55.5, rank: 1},
      %{channel_id: "UC_B", title: "Channel B", score: 44.5, rank: 2}
    ]
  }
}
```

### RevenueEstimatorLens

Estimates YouTube revenue based on video or channel view data using configurable CPM ranges.

**Endpoint:** `GET https://www.googleapis.com/youtube/v3/videos` (or `/channels` for channel-level estimation)

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `video_id` | string | Yes* | YouTube video ID to estimate revenue for |
| `channel_id` | string | Yes* | YouTube channel ID (uses total views) |
| `cpm_range` | object | No | CPM range in USD: `%{low: 1.0, high: 5.0}` |
| `niche` | string | No | Content niche for CPM adjustment |
| `region` | string | No | Primary audience region for CPM adjustment |
| `monetized_view_percentage` | float | No | Percentage of monetized views (0.0-1.0). Default: 0.75 |

*Either `video_id` or `channel_id` is required.

**Supported Niches:**

| Niche | Typical CPM Range (USD) |
|-------|------------------------|
| finance | $5.00 - $15.00 |
| business | $3.00 - $10.00 |
| technology | $3.00 - $8.00 |
| health | $2.50 - $7.00 |
| education | $2.00 - $6.00 |
| news | $2.00 - $6.00 |
| lifestyle | $1.50 - $5.00 |
| gaming | $1.50 - $5.00 |
| sports | $1.50 - $5.00 |
| entertainment | $1.00 - $4.00 |
| general | $1.00 - $5.00 |
| music | $0.50 - $3.00 |

**Supported Regions:**

| Region | CPM Multiplier |
|--------|---------------|
| US | 1.5x |
| UK | 1.3x |
| CA | 1.3x |
| AU | 1.2x |
| EU | 1.1x |
| Global | 1.0x |
| Asia | 0.6x |
| Brazil | 0.4x |
| India | 0.3x |

**Example:**

```elixir
alias Lux.Lenses.YouTube.RevenueEstimatorLens

# Estimate revenue for a specific video
{:ok, estimate} = RevenueEstimatorLens.focus(%{
  video_id: "dQw4w9WgXcQ",
  cpm_range: %{low: 2.0, high: 5.0},
  niche: "music",
  region: "global"
})

IO.puts("Estimated Revenue: $#{estimate.revenue_estimate.low} - $#{estimate.revenue_estimate.high}")
IO.puts("Average: $#{estimate.revenue_estimate.average}")
IO.puts("Monetized Views: #{estimate.monetized_views} / #{estimate.view_count}")

# Estimate channel revenue
{:ok, channel_estimate} = RevenueEstimatorLens.focus(%{
  channel_id: "UC_x5XG1OV2P6uZZ5FSM9Ttw",
  niche: "technology",
  region: "us",
  cpm_range: %{low: 3.0, high: 8.0}
})
```

**Response Format:**

```elixir
%{
  video_id: "dQw4w9WgXcQ",
  title: "Video Title",
  view_count: 1_000_000,
  monetized_views: 750_000,
  monetized_view_percentage: 0.75,
  revenue_estimate: %{
    low: 1500.0,
    high: 3750.0,
    average: 2625.0,
    currency: "USD"
  },
  cpm_used: %{
    low: 2.0,
    high: 5.0,
    average: 3.5,
    niche: "music",
    region: "global"
  },
  additional_metrics: %{
    rpm: 2.63,
    niche_multiplier: 3.0,
    region_multiplier: 1.0
  }
}
```

## Integration Module

The `Lux.Integrations.YouTube` module provides common configuration and utility functions:

```elixir
alias Lux.Integrations.YouTube

# Get base URL
YouTube.base_url()
# => "https://www.googleapis.com/youtube/v3"

# Get headers
YouTube.headers()
# => [{"content-type", "application/json"}, {"accept", "application/json"}]

# Get auth config
YouTube.auth()
# => %{type: :api_key, key: &Lux.Integrations.YouTube.api_key/0}

# Validate channel ID
YouTube.validate_channel_id("UC_x5XG1OV2P6uZZ5FSM9Ttw")
# => {:ok, "UC_x5XG1OV2P6uZZ5FSM9Ttw"}

# Validate video ID
YouTube.validate_video_id("dQw4w9WgXcQ")
# => {:ok, "dQw4w9WgXcQ"}

# Format dates for analytics
YouTube.format_date(~D[2024-01-15])
# => "2024-01-15"
```

## Usage Examples

### Building a Channel Growth Dashboard

```elixir
defmodule ChannelDashboard do
  alias Lux.Lenses.YouTube.{ChannelStatsLens, VideoAnalyticsLens, SearchTrendsLens}

  def generate_report(channel_id) do
    with {:ok, stats} <- ChannelStatsLens.focus(%{channel_id: channel_id}),
         {:ok, videos} <- fetch_recent_videos(channel_id) do
      %{
        channel: stats,
        recent_videos: videos,
        subscriber_velocity: calculate_subscriber_velocity(stats),
        avg_engagement: calculate_avg_engagement(videos)
      }
    end
  end

  defp fetch_recent_videos(channel_id) do
    SearchTrendsLens.focus(%{
      channel_id: channel_id,
      order: "date",
      max_results: 10,
      type: "video"
    })
  end

  defp calculate_subscriber_velocity(stats) do
    # Implementation depends on historical data
    %{current: stats.statistics.subscriber_count}
  end

  defp calculate_avg_engagement(videos) do
    videos.results
    |> Enum.map(fn v -> v.engagement_rate || 0 end)
    |> then(fn rates ->
      if length(rates) > 0 do
        Enum.sum(rates) / length(rates)
      else
        0
      end
    end)
  end
end
```

### Competitive Analysis Pipeline

```elixir
defmodule CompetitiveAnalysis do
  alias Lux.Lenses.YouTube.CompetitorAnalysisLens

  def run_analysis(channel_ids, opts \\ []) do
    CompetitorAnalysisLens.focus(%{
      channel_ids: channel_ids,
      metrics: Keyword.get(opts, :metrics, [
        "subscriberCount",
        "viewCount",
        "videoCount",
        "engagementRate"
      ]),
      include_rankings: true,
      scoring_method: Keyword.get(opts, :scoring_method, "weighted")
    })
  end

  def format_report({:ok, analysis}) do
    """
    Competitive Analysis Report
    ==========================

    Channels Analyzed: #{analysis.comparison.channel_count}

    Rankings:
    #{Enum.map_join(analysis.comparison.rankings, "\n", fn r ->
      "  ##{r.rank}. #{r.title} (Score: #{r.score})"
    end)}

    Leaders:
      Subscribers: #{analysis.comparison.leader.subscribers}
      Views: #{analysis.comparison.leader.views}
      Videos: #{analysis.comparison.leader.videos}
    """
  end
end
```

### Revenue Monitoring

```elixir
defmodule RevenueMonitor do
  alias Lux.Lenses.YouTube.{VideoAnalyticsLens, RevenueEstimatorLens}

  def monitor_video(video_id, opts \\ []) do
    with {:ok, analytics} <- VideoAnalyticsLens.focus(%{video_id: video_id}),
         {:ok, estimate} <- RevenueEstimatorLens.focus(%{
           video_id: video_id,
           cpm_range: %{
             low: Keyword.get(opts, :cpm_low, 2.0),
             high: Keyword.get(opts, :cpm_high, 5.0)
           },
           niche: Keyword.get(opts, :niche, "general"),
           region: Keyword.get(opts, :region, "global")
         }) do
      %{
        analytics: analytics,
        revenue: estimate.revenue_estimate,
        performance: %{
          views: analytics.statistics.view_count,
          engagement_rate: analytics.engagement_rate,
          estimated_revenue: estimate.revenue_estimate.average
        }
      }
    end
  end
end
```

## Error Handling

All lenses return `{:ok, result}` on success or `{:error, reason}` on failure:

```elixir
case ChannelStatsLens.focus(%{channel_id: "invalid"}) do
  {:ok, stats} ->
    IO.puts("Successfully fetched stats for #{stats.title}")
  {:error, reason} ->
    IO.puts("Error: #{reason}")
end
```

Common error scenarios:
- **Invalid channel/video ID**: Returns error with message about invalid format
- **Not found**: Returns error indicating the resource was not found
- **API quota exceeded**: Returns error from YouTube API
- **Invalid API key**: Returns authentication error

## Rate Limits and Quotas

The YouTube Data API v3 uses quota-based rate limiting:

| Endpoint | Cost (units) |
|----------|-------------|
| `channels.list` | 1 |
| `videos.list` | 1 |
| `search.list` | 100 |
| `youtubeAnalytics.reports.query` | 50 |

**Default daily quota:** 10,000 units

### Tips for Managing Quota

1. **Cache responses**: Store channel stats locally and refresh periodically
2. **Batch requests**: Use comma-separated IDs to fetch multiple resources in one call
3. **Use `part` parameter**: Only request the parts you need
4. **Implement rate limiting**: Add delays between requests
5. **Monitor usage**: Track quota consumption in Google Cloud Console

## Best Practices

### 1. Channel ID Validation

Always validate channel IDs before making API calls:

```elixir
case YouTube.validate_channel_id(channel_id) do
  {:ok, valid_id} ->
    ChannelStatsLens.focus(%{channel_id: valid_id})
  {:error, reason} ->
    {:error, reason}
end
```

### 2. Pagination

Handle pagination for search results:

```elixir
defp fetch_all_results(query, token \\ nil, acc \\ []) do
  params = %{query: query, max_results: 50}
  params = if token, do: Map.put(params, :page_token, token), else: params

  case SearchTrendsLens.focus(params) do
    {:ok, %{results: results, next_page_token: next_token}} when next_token != nil ->
      fetch_all_results(query, next_token, acc ++ results)
    {:ok, %{results: results}} ->
      {:ok, acc ++ results}
    {:error, reason} ->
      {:error, reason}
  end
end
```

### 3. Revenue Estimation Accuracy

For more accurate revenue estimates:

1. Use niche-specific CPM ranges
2. Consider regional audience distribution
3. Account for video length (mid-roll ads on videos >8min)
4. Factor in seasonal variations (Q4 typically has higher CPMs)
5. Adjust for audience demographics

### 4. Error Recovery

Implement retry logic for transient errors:

```elixir
def focus_with_retry(lens, params, max_retries \\ 3) do
  case lens.focus(params) do
    {:ok, result} ->
      {:ok, result}
    {:error, reason} when max_retries > 0 ->
      if String.contains?(reason, ["quota", "rate limit", "500"]) do
        :timer.sleep(1000)
        focus_with_retry(lens, params, max_retries - 1)
      else
        {:error, reason}
      end
    {:error, reason} ->
      {:error, reason}
  end
end
```

## API Reference

For complete API documentation, see:
- [YouTube Data API v3 Reference](https://developers.google.com/youtube/v3/docs)
- [YouTube Analytics API Reference](https://developers.google.com/youtube/analytics/v2)
- [API Quota Calculator](https://developers.google.com/youtube/v3/determine_quota_cost)

## License

This integration is part of the Spectral Finance Lux framework and is licensed under the same terms.
