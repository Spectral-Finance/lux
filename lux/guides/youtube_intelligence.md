# YouTube Content Intelligence System

AI-powered content analysis, optimization, and performance prediction for YouTube channels.

## Overview

The Content Intelligence System provides:
- **Video Analytics** — Performance metrics, engagement analysis, top videos
- **Trending Analysis** — Trending topics, niche analysis, content gaps
- **Content Optimizer** — Title, description, tag, and posting time optimization
- **Performance Predictor** — View/engagement predictions with confidence scoring
- **Metadata Generator** — Automated descriptions, chapters, cards, end screens

## Lenses

### VideoAnalytics

```elixir
# Get video performance stats
{:ok, stats} = Lux.Lenses.YouTube.Intelligence.VideoAnalytics.focus(%{
  action: "video_stats",
  video_id: "dQw4w9WgXcQ",
  auth: %{access_token: "ya29.xxx"}
})
# => %{views: 1_000_000, likes: 50_000, engagement_rate: 5.2, ...}

# Get channel overview
{:ok, channel} = VideoAnalytics.focus(%{
  action: "channel_stats",
  channel_id: "UC...",
  auth: %{access_token: "ya29.xxx"}
})

# Find top performing videos
{:ok, top} = VideoAnalytics.focus(%{
  action: "top_videos",
  channel_id: "UC...",
  max_results: 10,
  auth: %{access_token: "ya29.xxx"}
})
```

### TrendingAnalysis

```elixir
# Get trending videos in a region
{:ok, trending} = TrendingAnalysis.focus(%{
  action: "trending",
  region: "US",
  category_id: "28",  # Science & Technology
  auth: %{access_token: "ya29.xxx"}
})

# Analyze a niche
{:ok, niche} = TrendingAnalysis.focus(%{
  action: "niche_analysis",
  query: "elixir programming",
  auth: %{access_token: "ya29.xxx"}
})

# Find content gaps (no API needed)
{:ok, gaps} = TrendingAnalysis.focus(%{
  action: "content_gaps",
  videos: [%{title: "..."}, ...]
})
```

## Prisms

### ContentOptimizer

```elixir
# Optimize a title
{:ok, result} = ContentOptimizer.handler(%{
  action: "optimize_title",
  title: "Learning Elixir"
}, [])
# => %{suggestions: ["Ultimate: Learning Elixir", ...], score: 55, tips: [...]}

# Full optimization
{:ok, result} = ContentOptimizer.handler(%{
  action: "full_optimization",
  title: "Elixir Tutorial",
  description: "Learn Elixir from scratch",
  niche: "programming",
  tags: ["elixir", "functional"]
}, [])
```

### PerformancePredictor

```elixir
{:ok, prediction} = PerformancePredictor.handler(%{
  title: "Ultimate Guide to Phoenix LiveView",
  tags: ["phoenix", "liveview", "elixir"],
  duration_minutes: 12,
  channel_subscribers: 10_000,
  channel_avg_views: 2000
}, [])
# => %{
#   predicted_views: %{low: 800, mid: 1600, high: 3200},
#   predicted_engagement: %{rate: 4.2, ...},
#   confidence: 0.35,
#   recommendations: [...]
# }
```

### MetadataGenerator

```elixir
# Generate description
{:ok, desc} = MetadataGenerator.handler(%{
  action: "description",
  topic: "Elixir OTP",
  key_points: ["GenServer", "Supervisors", "Applications"],
  niche: "programming"
}, [])

# Generate chapters
{:ok, chapters} = MetadataGenerator.handler(%{
  action: "chapters",
  topic: "Tutorial",
  key_points: ["Setup", "Basics", "Advanced", "Deploy"],
  duration_minutes: 20
}, [])
```

## Scoring System

### Title Score (0-100)
- Length 40-70 chars: +15
- Contains numbers: +10
- Power words (ultimate, guide, best...): +10
- Brackets/parentheses: +5
- Question format: +5

### SEO Score (0-100)
- Description > 100 chars: +20
- 5+ tags: +20
- Tags match title: +20
- Description > 500 chars: +10

### Duration Score (0-100)
- 8-15 min (optimal): 90
- 5-20 min: 75
- 3-30 min: 60
- Very short/long: 40-50
