# Telegram Group Management Guide

This guide covers the Telegram group management features in Lux, including member management, content moderation, permission control, and admin logging.

## Modules

| Module | Type | Description |
|--------|------|-------------|
| `ManageGroupMembers` | Prism | Ban, unban, restrict, promote, kick members |
| `ManageGroupSettings` | Prism | Group title, description, permissions, slow mode, pins |
| `ContentModeration` | Prism | Spam detection, content filtering, auto-moderation |
| `AdminLogger` | GenServer | Audit log for admin actions with querying |
| `GetGroupAdmins` | Lens | Retrieve group administrator list |
| `GetGroupMemberCount` | Lens | Get group member count |

## Member Management

```elixir
# Ban a user
ManageGroupMembers.handler(%{
  action: "ban",
  chat_id: -100123456,
  user_id: 789,
  token: bot_token,
  revoke_messages: true  # delete their messages too
}, nil)

# Restrict a user (mute)
ManageGroupMembers.handler(%{
  action: "restrict",
  chat_id: -100123456,
  user_id: 789,
  token: bot_token,
  permissions: %{can_send_messages: false},
  until_date: DateTime.utc_now() |> DateTime.add(3600) |> DateTime.to_unix()
}, nil)

# Promote to admin
ManageGroupMembers.handler(%{
  action: "promote",
  chat_id: -100123456,
  user_id: 789,
  token: bot_token,
  admin_rights: %{
    can_delete_messages: true,
    can_restrict_members: true,
    can_pin_messages: true
  }
}, nil)
```

## Content Moderation

### Spam Detection

Built-in spam patterns detect common scam messages:

```elixir
{:ok, %{result: %{is_spam: true, spam_score: 80}}} =
  ContentModeration.handler(%{
    action: "check_spam",
    text: "Earn $5000 per day! Click here for free crypto!"
  }, nil)
```

### Content Rules

```elixir
{:ok, %{result: %{compliant: false, violations: [:forbidden_words, :contains_links]}}} =
  ContentModeration.handler(%{
    action: "check_content",
    text: "Buy cheap stuff at http://spam.com",
    rules: %{
      forbidden_words: ["cheap", "buy"],
      no_links: true,
      max_length: 500
    }
  }, nil)
```

### Auto-Moderation

Combines spam detection and content rules, recommends action severity:

```elixir
{:ok, %{result: %{severity: :ban, should_act: true}}} =
  ContentModeration.handler(%{
    action: "auto_moderate",
    text: "FREE MONEY! 100% guaranteed profit! Click here!",
    rules: %{no_links: true}
  }, nil)
```

Severity levels: `:none` → `:warn` → `:restrict` → `:ban`

## Admin Logging

```elixir
{:ok, pid} = AdminLogger.start_link()

# Log an action
AdminLogger.log_action(pid, %{
  action: :ban,
  chat_id: -100123,
  admin_id: 1,
  target_user_id: 456,
  reason: "Spam"
})

# Query by filters
{:ok, bans} = AdminLogger.query(pid, %{action: :ban, chat_id: -100123})
{:ok, recent} = AdminLogger.recent(pid, 10)
```

## Group Settings

```elixir
# Set slow mode (30 seconds between messages)
ManageGroupSettings.handler(%{
  action: "set_slow_mode",
  chat_id: -100123456,
  slow_mode_delay: 30,
  token: bot_token
}, nil)

# Pin a message
ManageGroupSettings.handler(%{
  action: "pin_message",
  chat_id: -100123456,
  message_id: 42,
  token: bot_token
}, nil)
```
