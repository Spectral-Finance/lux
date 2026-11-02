# Twitter Automation and Engagement in Lux

## Overview

The `Lux.Integrations.Twitter.Automation` suite delivers enterprise-grade autonomous social engagement, scheduled publishing, content curation, and audience interaction for Twitter (X). Built for autonomous AI agents, it guarantees high reliability, rate-limit compliance, and safety bounds:

- **Priority Queue & Tweet Scheduling**: Time-based and priority-weighted tweet/thread scheduling with retry policies.
- **Content Calendar Management**: Recurring weekly time slots, content pillar alignment, and automated batch draft scheduling.
- **Auto-Reply Management**: Mention tracking, sentiment/intent classification, contextual response generation, anti-spam heuristics, and per-user cooldowns.
- **Content Curation**: Algorithmic discovery of viral industry content, quality scoring, deduplication, and automated quote-tweet proposal drafting.
- **Rule-Based Engagement Engine**: Declarative condition matching (keywords, follower counts, engagement velocity) with strict daily safety caps (likes, retweets, replies, follows).
- **Follow / Unfollow Management**: Reciprocal follow analysis, stale non-mutual identification, and protected whitelist management.
- **Direct Message Automation**: Follower welcome DMs, automated FAQ routing, conversational sessions, and compliance with opt-out standards (`STOP`).
- **Prisms & Beams**: 7 specialized Prisms and the `Lux.Beams.Twitter.AutomationBeam` pipeline.

---

## Architecture

```
                                  +------------------------------------+
                                  |     Twitter Interactions / API     |
                                  +------------------------------------+
                                                    |
                                                    v
                                  +------------------------------------+
                                  |       AutomationBeam Pipeline      |
                                  +------------------------------------+
                                                    |
             +--------------------+-----------------+--------------------+
             |                    |                 |                    |
             v                    v                 v                    v
     +---------------+    +---------------+  +---------------+    +---------------+
     | TweetScheduler|    | ContentCurator|  | EngagementRule|    | DMAutomation  |
     | - Priority Q  |    | - Scoring     |  | - Conditions  |    | - Welcome DMs |
     | - Retries     |    | - Quote draft |  | - Daily caps  |    | - FAQ routing |
     | - Calendar    |    | - Deduplication| | - Dispatcher  |    | - Opt-outs    |
     +---------------+    +---------------+  +---------------+    +---------------+
             |                    |                 |                    |
             +--------------------+-----------------+--------------------+
                                                    |
                                                    v
                                  +------------------------------------+
                                  |   Twitter Execution Lenses/Client  |
                                  +------------------------------------+
```

---

## 1. Tweet Scheduling & Priority Queue

The `Scheduler` manages timed execution with priority weighting (`:high` > `:normal` > `:low`) and retry backoff:

```elixir
alias Lux.Integrations.Twitter.Automation.Scheduler

queue = Scheduler.new_queue()

# Schedule high-priority breaking news:
{:ok, queue, item} =
  Scheduler.schedule(queue, %{
    text: "Breaking: Spectral Lux 2.0 autonomous agent framework released!",
    scheduled_at: "2024-03-01T15:00:00Z",
    priority: :high,
    media_ids: ["media_chart_101"]
  })

# Retrieve due items:
due_items = Scheduler.get_due_items(queue, DateTime.utc_now())

# Mark as published once posted:
{:ok, queue, _} = Scheduler.mark_published(queue, item.id, "tw_1763456789")
```

---

## 2. Content Calendar Management

Define recurring slots for weekly publishing rhythms:

```elixir
alias Lux.Integrations.Twitter.Automation.ContentCalendar

calendar =
  ContentCalendar.new_calendar(timezone: "Etc/UTC")
  |> elem(1)
  |> ContentCalendar.add_slot(1, "09:00", :market_update) # Monday 9 AM
  |> elem(1)
  |> ContentCalendar.add_slot(3, "14:00", :education)     # Wednesday 2 PM
  |> elem(1)
  |> ContentCalendar.add_slot(5, "17:00", :community)     # Friday 5 PM
  |> elem(1)

drafts = [
  %{text: "Weekly Ethereum L2 metrics & gas overview", topic: :market_update},
  %{text: "How account abstraction enables one-click trading", topic: :education}
]

# Automated pairing into upcoming schedule:
schedule_plan = ContentCalendar.plan_schedule(calendar, drafts)
```

---

## 3. Auto-Reply Management

Monitors mentions and generates contextual responses with cooldown guards:

```elixir
alias Lux.Integrations.Twitter.Automation.AutoReplyManager

# Check eligibility against 30-min per-user cooldown and blacklist:
{:ok, eligible?, reason} = AutoReplyManager.should_reply?(incoming_tweet, cooldown_state)

if eligible? do
  {:ok, reply_text} = AutoReplyManager.generate_reply(incoming_tweet)
  #=> "Hello @developer! You can explore our complete documentation and guides here: https://docs.lux.xyz"

  # Post reply via Lux lens and update cooldown:
  cooldown_state = AutoReplyManager.update_cooldown(cooldown_state, incoming_tweet.author_id)
end
```

---

## 4. Content Curation & Quality Scoring

Scans and ranks industry tweets using engagement velocity, media presence, and author authority:

```elixir
alias Lux.Integrations.Twitter.Automation.ContentCurator

candidates = search_results_from_twitter()
seen_ids = ["already_curated_id_1", "already_curated_id_2"]

ranked = ContentCurator.rank_content(candidates, seen_ids, min_score: 25.0)

top_pick = hd(ranked)
top_pick.recommended_action    #=> :quote_tweet
top_pick.suggested_commentary  #=> "Great insights by @vitalik on this development..."
```

---

## 5. Engagement Rules Engine & Daily Caps

Enforces declarative rules while strictly adhering to Twitter API rate limits:

```elixir
alias Lux.Integrations.Twitter.Automation.EngagementRulesEngine

rules = [
  %{
    name: "Engage with Rollup Researchers",
    conditions: %{
      keywords_any: ["rollup", "eip-4844", "validium"],
      min_likes: 25,
      min_followers: 1000
    },
    actions: [:like, :retweet]
  }
]

daily_usage = %{like: 12, retweet: 4}
custom_caps = %{like: 50, retweet: 25}

{:ok, result} = EngagementRulesEngine.evaluate(tweet, rules, daily_usage, custom_caps)

result.approved_actions   #=> [:like, :retweet]
result.throttled_actions  #=> []
```

---

## 6. Follow / Unfollow Management

Safe relationship management with whitelist protection:

```elixir
alias Lux.Integrations.Twitter.Automation.FollowManager

# Protect founders and partners:
state = FollowManager.init_state(["founder_id", "partner_id"])

# Record new follow:
state = FollowManager.record_follow(state, "influencer_123")

# Identify accounts followed > 7 days ago that do not follow back:
unfollow_candidates = FollowManager.identify_unfollow_candidates(state, current_followers, 7)
```

---

## 7. Direct Message Automation

Automated onboarding and keyword FAQ routing with opt-out compliance:

```elixir
alias Lux.Integrations.Twitter.Automation.DMAutomation

# Welcome new followers:
welcome_dm = DMAutomation.generate_welcome_message(%{username: "new_builder"})

# Handle inbound message:
{:ok, response, opted_out_set} = DMAutomation.process_message(incoming_dm, opted_out_set)

response.action      #=> :reply
response.reply_text  #=> "You can view our technical architecture and documentation at https://docs.lux.xyz"
```

---

## 8. Specialized Prisms Reference

| Prism | Module | Function |
|---|---|---|
| `ScheduleTweet` | `Lux.Prisms.Twitter.Automation.ScheduleTweet` | Schedules tweets/threads with priority ordering |
| `ManageCalendar` | `Lux.Prisms.Twitter.Automation.ManageCalendar` | Adds recurring slots and plans batch schedules |
| `ProcessAutoReply` | `Lux.Prisms.Twitter.Automation.ProcessAutoReply` | Evaluates mention eligibility and generates replies |
| `CurateContent` | `Lux.Prisms.Twitter.Automation.CurateContent` | Scores candidate tweets and recommends actions |
| `EvaluateEngagementRules` | `Lux.Prisms.Twitter.Automation.EvaluateEngagementRules` | Matches rules and enforces daily action caps |
| `ManageFollows` | `Lux.Prisms.Twitter.Automation.ManageFollows` | Evaluates target accounts and safe unfollow lists |
| `AutomateDM` | `Lux.Prisms.Twitter.Automation.AutomateDM` | Generates welcome DMs and processes inbound queries |

---

## 9. AutomationBeam Pipeline

Connects rule evaluation, mention response, and scheduling into a unified workflow:

```elixir
alias Lux.Beams.Twitter.AutomationBeam

{:ok, result} =
  AutomationBeam.process_tweet(incoming_tweet,
    rules: my_engagement_rules,
    daily_usage: current_daily_usage,
    cooldown_state: active_cooldowns
  )

result.engagement_evaluation #=> matched rules & approved actions
result.auto_reply            #=> contextual response if eligible
```
