# YouTube Community Management and Engagement in Lux

The YouTube Community Management and Engagement subsystem empowers autonomous AI agents in Lux to monitor, moderate, analyze, and engage with viewer communities on YouTube.

By combining rule-based filtering, contextual NLP sentiment and intent classification, persona-driven reply generation, and automated community post scheduling, Lux agents can act as 24/7 community managers for creators and enterprises.

---

## Architecture Overview

The system is organized into modular components under `Lux.Community.YouTube`:

```
Lux.Community.YouTube
├── CommentManager           # Thread ingestion, state tracking, and status transitions
├── SentimentAnalyzer        # Polarity scoring (-1.0 to +1.0) and intent classification
├── SpamModerator            # Spam, scam, promotional, and toxicity detection
├── ResponseGenerator        # Context-aware persona reply synthesis
└── CommunityPostScheduler   # Rich community post and poll lifecycle manager
```

A first-class agent prism (`Lux.Prisms.YouTubeCommunityPrism`) wraps these capabilities, allowing any Lux agent or company objective to trigger community actions declaratively.

---

## 1. Unified Interface (`Lux.Community.YouTube`)

The top-level `Lux.Community.YouTube` module provides high-level convenience functions:

```elixir
alias Lux.Community.YouTube

# Process an incoming raw comment end-to-end
raw_comment = %{
  id: "yt_12345",
  author_name: "AliceDev",
  text: "Great tutorial on Lux! Could you make a video on multi-agent companies next?"
}

result = YouTube.process_comment(raw_comment)
# Returns:
# %{
#   original_text: "Great tutorial on Lux!...",
#   author: "AliceDev",
#   moderation: %{is_spam: false, is_toxic: false, recommended_action: :approve, ...},
#   sentiment: %{classification: :positive, intent: :inquiry, score: 0.5, ...},
#   suggested_reply: "Hey AliceDev! Thanks so much for reaching out...",
#   should_publish_reply: true
# }
```

---

## 2. Comment Moderation (`SpamModerator`)

The `SpamModerator` detects malicious links, crypto giveaways, WhatsApp scams, excessive capitalization, and toxic keywords:

```elixir
alias Lux.Community.YouTube.SpamModerator

verdict = SpamModerator.evaluate_comment("WHATSAPP ME FOR 100x SIGNALS +1-800-FAKE http://scam.xyz")

verdict.is_spam            #=> true
verdict.recommended_action #=> :ban_author
verdict.reasons            #=> ["Detected financial/crypto scam contact recruitment pattern", ...]
```

---

## 3. Sentiment & Intent Analysis (`SentimentAnalyzer`)

Analyzes text polarity and categorizes viewer intent into `:question`, `:praise`, `:complaint`, `:suggestion`, or `:neutral`:

```elixir
alias Lux.Community.YouTube.SentimentAnalyzer

analysis = SentimentAnalyzer.analyze_comment("Audio volume too quiet, had to turn my speakers all the way up")

analysis.classification  #=> :neutral
analysis.intent          #=> :complaint
analysis.score           #=> 0.0
```

Batch analysis is also supported across comment collections:

```elixir
batch_stats = SentimentAnalyzer.analyze_batch([
  %{text: "Loved this video!"},
  %{text: "Horrible audio quality"},
  %{text: "Where is the repo?"}
])

batch_stats.total_analyzed      #=> 3
batch_stats.inquiry_count       #=> 1
batch_stats.sentiment_verdict   #=> :mixed
```

---

## 4. Persona-Driven Response Generation (`ResponseGenerator`)

The response generator tailors replies based on viewer intent and creator persona:

```elixir
alias Lux.Community.YouTube.ResponseGenerator

reply = ResponseGenerator.generate_response(
  "How do I configure the EVM bridge in Lux?",
  "DeveloperDan",
  persona: "TechLead"
)

# Output:
# "Hey DeveloperDan, great question! For EVM bridge setup, verify your RPC endpoints in config/config.exs and check the livemd guide."
```

---

## 5. Community Post Scheduling (`CommunityPostScheduler`)

Manage scheduled announcements, updates, and interactive viewer polls:

```elixir
alias Lux.Community.YouTube.CommunityPostScheduler

post_params = %{
  content: "Which framework integration should Lux build next?",
  type: :poll,
  options: ["LangChain", "CrewAI", "AutoGen", "Custom Elixir"],
  scheduled_at: ~U[2026-11-05 18:00:00Z]
}

{:ok, scheduled_post} = CommunityPostScheduler.create_post(post_params)
```

Optimal peak engagement posting windows can be computed dynamically via `CommunityPostScheduler.recommend_optimal_window/1`.

---

## 6. Using with Lux Prisms & Agents

Any Lux agent can invoke the `YouTubeCommunityPrism` within an objective:

```elixir
defmodule MyApp.Agents.CommunityManagerAgent do
  use Lux.Agent,
    name: "YouTube Community Manager",
    description: "Moderates community comments and crafts timely creator replies",
    prisms: [Lux.Prisms.YouTubeCommunityPrism]
end
```

Or invoke the prism programmatically:

```elixir
alias Lux.Prisms.YouTubeCommunityPrism

{:ok, result} = YouTubeCommunityPrism.run(%{
  action: "moderate",
  payload: %{text: "Check out free bitcoin giveaway at bit.ly/fake"}
})

assert result.result.is_spam == true
```
