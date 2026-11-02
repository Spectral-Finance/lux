# Twitter Analytics and Monitoring Guide

This guide details the architecture, statistical formulations, and operational workflows for Twitter (X) Analytics and Real-Time Monitoring in Lux.

---

## 1. Architecture Overview

Lux provides a unified analytics engine designed for autonomous agents to track brand sentiment, measure tweet virality, monitor audience trajectories, and react automatically to anomalous engagement events.

```mermaid
flowchart TD
    Agent[Autonomous Agent] --> Beam[Lux.Beams.Twitter.MonitoringBeam]
    Agent --> Prism[Lux.Prisms.TwitterAnalyticsPrism]
    
    Beam --> Prism
    Prism --> Facade[Lux.Integrations.Twitter.Analytics]
    
    Facade --> Engagement[EngagementTracker\n(Impressions, ER, Virality Score)]
    Facade --> Growth[FollowerGrowthTracker\n(Net change, Daily velocity)]
    Facade --> Hashtag[HashtagAnalyzer\n(Frequency, Co-occurrence)]
    Facade --> Sentiment[SentimentAnalyzer\n(VADER-style Lexicon & Emojis)]
    Facade --> Alert[AlertEngine\n(Spike detection, Risk triggers)]
    Facade --> Report[ReportGenerator\n(Executive Markdown & JSON Briefs)]
```

---

## 2. Metrics & Mathematical Formulations

### 2.1 Engagement Rate per Impression (ER)
Measures the percentage of impressions that generated active engagement:
$$\text{Engagement Rate} = \frac{\text{Likes} + \text{Retweets} + \text{Replies} + \text{Quotes} + \text{Bookmarks}}{\max(\text{Impressions}, 1)}$$

### 2.2 Virality & Amplification Score
Quantifies social syndication vs passive consumption:
$$\text{Virality Score} = \frac{\text{Retweets} + \text{Quotes}}{\max(\text{Total Engagements}, 1)}$$

### 2.3 Compound Sentiment Score
Scores mention texts and social replies across a normalized range of $[-1.0, 1.0]$:
$$\text{Compound Score} = \frac{\text{PosScore} - \text{NegScore}}{\text{PosScore} + \text{NegScore} + 1.0}$$
- **Positive**: Score $> +0.15$
- **Neutral**: $-0.15 \le \text{Score} \le +0.15$
- **Negative**: Score $< -0.15$

---

## 3. Submodules & Capabilities

### 3.1 Engagement Tracker (`Lux.Integrations.Twitter.Analytics.EngagementTracker`)
- Aggregates raw public and organic metrics across tweet collections.
- Ranks top-performing content by total interactions.
- Computes standard social media marketing KPI rates.

### 3.2 Follower Growth Tracker (`Lux.Integrations.Twitter.Analytics.FollowerGrowthTracker`)
- Ingests time-series snapshots of account metadata.
- Computes net follower gains, percentage growth, and daily run-rate velocities.
- Tracks follower-to-following ratios.

### 3.3 Hashtag Analyzer (`Lux.Integrations.Twitter.Analytics.HashtagAnalyzer`)
- Extracts hashtag occurrences with case-insensitive normalization.
- Aggregates total engagement attributable to specific hashtags.
- Identifies the highest-performing tweet for each hashtag.

### 3.4 Sentiment Analyzer (`Lux.Integrations.Twitter.Analytics.SentimentAnalyzer`)
- Domain-tuned lexicon tailored for Web3, AI, and developer communities (e.g. *bullish*, *breakthrough*, *scam*, *hack*, *dump*).
- Comprehensive emoji sentiment weighting (🚀, 🔥, 💎 vs 💩, 😡, 🚨).
- Batch statistics providing positive, neutral, and negative percentage distributions.

### 3.5 Real-Time Alert Engine (`Lux.Integrations.Twitter.Analytics.AlertEngine`)
- Configurable thresholds for instant anomaly detection:
  - Viral spikes: `like_threshold`, `retweet_threshold`.
  - Social risk alerts: `negative_sentiment_threshold` (e.g. $> 30\%$).
  - Audience drop warnings: `min_follower_change` (e.g. $< -50$).

### 3.6 Executive Report Generator (`Lux.Integrations.Twitter.Analytics.ReportGenerator`)
- Produces automated Markdown briefings suitable for leadership dashboards or Discord/Telegram agent relays.

---

## 4. Autonomous Agent Prism & Beam Workflows

### 4.1 Running via Prism
```elixir
{:ok, %{result: report}} =
  Lux.Prisms.TwitterAnalyticsPrism.run(%{
    action: "run_full_audit",
    payload: %{
      tweets: [
        %{"id" => "1", "text" => "Introducing Lux 2.0! #AI #Web3", "public_metrics" => %{"like_count" => 350, "retweet_count" => 80, "reply_count" => 25, "impression_count" => 10000}}
      ],
      mentions: [
        "Lux 2.0 is an absolute game changer! 🚀🔥",
        "Amazing release, love the documentation."
      ],
      thresholds: %{retweet_threshold: 50}
    }
  })
```

### 4.2 Running the Monitoring Beam
```elixir
{:ok, summary} =
  Lux.Beams.Twitter.MonitoringBeam.run(%{
    tweets: tweets_list,
    mentions: mentions_list,
    handle: "@Spectral_Fi"
  })
```
