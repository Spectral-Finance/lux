# YouTube Community Management Guide

## Comment Manager

```elixir
{:ok, pid} = CommentManager.start_link()

# Analyze comments (sentiment, spam, language, questions)
{:ok, analysis} = CommentManager.analyze_comment(pid, %{id: "c1", text: "Amazing video!", author: "Alice"})
# %{sentiment: :positive, is_spam: false, is_question: false, language: "en"}

# Auto-generate responses
{:ok, resp} = CommentManager.generate_response(pid, %{text: "How does this work?"})
# %{response: %{action: :reply, text: "Great question! Let me look into that."}}

# Batch analysis
{:ok, results} = CommentManager.batch_analyze(pid, comments)
{:ok, stats} = CommentManager.get_stats(pid)
```

## Post Scheduler

```elixir
{:ok, pid} = PostScheduler.start_link()

# Schedule community posts
PostScheduler.schedule_post(pid, %{text: "New video tomorrow!", scheduled_at: ~U[2026-03-10 12:00:00Z]})

# Cross-platform
PostScheduler.schedule_post(pid, %{text: "Big news!", platforms: [:youtube, :twitter]})

# Campaigns
PostScheduler.create_campaign(pid, %{name: "Summer Launch", start_date: ~D[2026-06-01]})

# Get due posts
{:ok, due} = PostScheduler.get_due_posts(pid)
```

## Spam Detector

```elixir
result = SpamDetector.detect("Sub4sub check my channel!")
# %{is_spam: true, score: 75, severity: :critical, recommended_action: :ban_and_delete}

batch = SpamDetector.batch_detect(["Good comment", "SPAM sub4sub click bit.ly/x"])
# %{total: 2, spam_count: 1, spam_rate: 50.0}
```
