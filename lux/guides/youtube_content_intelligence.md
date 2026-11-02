# YouTube Content Intelligence System in Lux

The YouTube Content Intelligence subsystem empowers autonomous Lux agents to analyze channel telemetry, forecast video performance, optimize Click-Through Rates (CTR), predict ideal upload times, and generate SEO-compliant metadata packages.

This turns Lux agents into data-driven YouTube growth strategists capable of continuous channel optimization without manual intervention.

---

## Architecture Overview

The system is organized modularly under `Lux.YouTube.ContentIntelligence`:

```
Lux.YouTube.ContentIntelligence
├── PerformanceAnalytics     # Velocity scoring, view benchmarks, retention curve drop detection
├── AudienceEngagement       # Cohort loyalty, subscriber watch ratio, traffic source decomposition
├── RecommendationEngine     # Topic clustering, content gap identification, next-best-video modeling
├── PostingTimePredictor     # Audience activity heatmaps, timezone weighting, lead-time offsets
├── TitleThumbnailOptimizer  # Psychological CTR scoring, A/B angle variants, mobile truncation alerts
├── MetadataGenerator        # Formatted chapter timestamps, SEO descriptions, bounded tag packages (<500 chars)
└── TrendingTopicAnalyzer    # Search volume momentum, competitive saturation, evergreen classification
```

A first-class agent prism (`Lux.Prisms.YouTubeContentIntelligencePrism`) exposes all capabilities to Lux agents, Beams, and Companies.

---

## 1. Unified Interface (`Lux.YouTube.ContentIntelligence`)

The high-level facade provides end-to-end video auditing:

```elixir
alias Lux.YouTube.ContentIntelligence

video_payload = %{
  title: "Building Autonomous AI Agents in Elixir [Full Guide]",
  stats: %{
    views: 15_000,
    watch_time_seconds: 4_500_000.0,
    duration_seconds: 600.0,
    published_hours_ago: 24.0,
    likes: 900,
    comments: 180,
    shares: 95,
    retention_curve: [
      %{timestamp_seconds: 0, percentage_retained: 100.0},
      %{timestamp_seconds: 30, percentage_retained: 72.0},
      %{timestamp_seconds: 600, percentage_retained: 45.0}
    ]
  },
  audience: %{
    returning_viewers: 6_000,
    sub_watch_time_pct: 45.0
  },
  thumbnail: %{
    overlay_text_word_count: 3,
    contrast_ratio: 5.5,
    has_human_face: true
  }
}

audit = ContentIntelligence.audit_video(video_payload)

audit.overall_health_score       #=> 78.4
audit.verdict                    #=> :stable_grower
audit.performance.views_per_hour #=> 625.0
audit.actionable_recommendations #=> ["Shorten title...", "Tighten video intro..."]
```

---

## 2. Video Performance Analytics (`PerformanceAnalytics`)

Evaluates retention curve health, velocity (VPH), and benchmarks performance against historical channel baselines:

```elixir
alias Lux.YouTube.ContentIntelligence.PerformanceAnalytics

summary = PerformanceAnalytics.evaluate_performance(
  %{views: 10_000, watch_time_seconds: 3_000_000.0, duration_seconds: 600.0, published_hours_ago: 20.0},
  %{avg_views_at_24h: 5_000.0}
)

summary.average_percentage_viewed  #=> 50.0%
summary.benchmark_multiplier       #=> 2.0x channel average
summary.retention_health           #=> :good
```

---

## 3. Title & Thumbnail Optimization (`TitleThumbnailOptimizer`)

Audits title psychology, power words, numbers, and brackets, while checking against mobile viewport truncation (65 chars limit):

```elixir
alias Lux.YouTube.ContentIntelligence.TitleThumbnailOptimizer

analysis = TitleThumbnailOptimizer.analyze_title("The Ultimate Multi-Agent Architecture Guide [2026]")

analysis.ctr_potential_score    #=> 85.0
analysis.mobile_truncation_risk #=> false
analysis.power_words_found      #=> ["ultimate", "guide"]

# Generate 4 psychological angle variants for A/B testing
variants = TitleThumbnailOptimizer.generate_variants("Autonomous AI Agents")
# Generates:
# - Authority: "The Ultimate Autonomous AI Agents Blueprint [2026 Guide]"
# - Curiosity: "Why Most Developers Fail at Autonomous AI Agents (And How to Fix It)"
# - Personal Story: "I Built a Production Autonomous AI Agents in 24 Hours"
# - Negative Warning: "Stop Doing Autonomous AI Agents Like This! (Fatal Mistakes)"
```

---

## 4. Metadata & SEO Tag Generator (`MetadataGenerator`)

Generates structured descriptions with timestamps, resource links, hashtags, and strictly character-bounded tags (<495 characters):

```elixir
alias Lux.YouTube.ContentIntelligence.MetadataGenerator

package = MetadataGenerator.generate_package(%{
  title: "Building Production Multi-Agent Systems in Elixir",
  niche: "AI Engineering",
  summary: "Comprehensive guide to scaling Lux agents with OTP supervision.",
  keywords: ["elixir", "lux", "agents", "otp"],
  links: ["https://lux.agent", "https://github.com/Spectral-Finance/lux"]
})

package.description             #=> Formatted with chapter timestamps, links, and hashtags
package.tags_total_characters   #=> <= 495 chars (strictly under YouTube limit)
package.tags_comma_separated    #=> "building production multi-agent...,ai engineering,..."
```

---

## 5. Optimal Upload Timing Prediction (`PostingTimePredictor`)

Calculates recommended day, peak UTC hour, and lead-time buffering for video processing:

```elixir
alias Lux.YouTube.ContentIntelligence.PostingTimePredictor

prediction = PostingTimePredictor.predict_optimal_time(%{timezone: "America/New_York"})

prediction.recommended_day_of_week        #=> :thursday
prediction.recommended_utc_hour           #=> 19 (2:00 PM EST)
prediction.recommended_lead_time_minutes  #=> 45
```

---

## 6. Topic Recommendations & Gap Analysis (`RecommendationEngine`)

Recommends high-retention video topics based on past top performers and discovers untapped audience search queries:

```elixir
alias Lux.YouTube.ContentIntelligence.RecommendationEngine

# Uncover content gaps
gaps = RecommendationEngine.identify_content_gaps(
  ["elixir rust ffi", "distributed supervision trees"],
  ["Distributed Supervision Trees Guide"]
)
# Returns gap for "elixir rust ffi" with urgency and opportunity score
```

---

## 7. Using with Lux Prisms & Agents

Integrate `YouTubeContentIntelligencePrism` directly into autonomous agents:

```elixir
defmodule MyApp.Agents.YouTubeStrategistAgent do
  use Lux.Agent,
    name: "YouTube Strategist Agent",
    description: "Monitors video telemetry, optimizes metadata, and recommends publishing schedules",
    prisms: [Lux.Prisms.YouTubeContentIntelligencePrism]
end
```

Or call the prism dynamically:

```elixir
alias Lux.Prisms.YouTubeContentIntelligencePrism

{:ok, response} = YouTubeContentIntelligencePrism.run(%{
  action: "optimize_title",
  payload: %{title: "Building Production Multi-Agent Systems with Lux"}
})

assert response.result.ctr_potential_score > 70.0
```
