# Discord Core Prisms Guide

Core Discord server operations: messages, channels, moderation, events.

## Message Management

```elixir
# Send
{:ok, msg} = MessageManagement.send_message("channel_id", %{content: "Hello!", reply_to: "msg_id"}, opts)

# Edit / Delete
MessageManagement.edit_message("ch", "msg_id", %{content: "Updated"}, opts)
MessageManagement.delete_message("ch", "msg_id", opts)

# Bulk delete (2-100 messages)
MessageManagement.bulk_delete("ch", ["m1", "m2", "m3"], opts)

# History, Pin, React
{:ok, messages} = MessageManagement.get_history("ch", %{limit: 50}, opts)
MessageManagement.pin_message("ch", "msg_id", opts)
MessageManagement.add_reaction("ch", "msg_id", "👍", opts)
```

## Channel Management

```elixir
# CRUD
{:ok, ch} = ChannelManagement.create_channel("guild_id", %{name: "general", type: :text}, opts)
ChannelManagement.edit_channel("ch_id", %{name: "renamed", topic: "New topic"}, opts)
ChannelManagement.delete_channel("ch_id", opts)

# Permissions
ChannelManagement.set_permission("ch_id", "role_id", %{type: 0, allow: 1024, deny: 0}, opts)

# Archive/Unarchive
ChannelManagement.archive_channel("ch_id", opts)
```

## Moderation

```elixir
{:ok, pid} = Moderation.start_link()

# Content filtering (built-in: spam links, all caps)
{:ok, result} = Moderation.check_content(pid, "Join discord.gg/spam!")
# %{clean: false, violations: [%{action: :delete, severity: :high}]}

Moderation.add_filter(pid, %{pattern: "badword", action: :ban, severity: :critical})
Moderation.add_filter(pid, %{pattern: ~r/regex/i, action: :delete})

# Warnings
Moderation.warn_user(pid, "user_id", "Spamming")
{:ok, warnings} = Moderation.get_warnings(pid, "user_id")

# Discord API actions
Moderation.timeout_user("guild", "user", 3600, opts)  # 1h timeout
Moderation.ban_user("guild", "user", %{delete_message_seconds: 86400}, opts)
Moderation.kick_user("guild", "user", opts)
```

## Event Handling

```elixir
{:ok, pid} = EventHandling.start_link()

{:ok, event} = EventHandling.create_event(pid, %{
  name: "Game Night", start_time: ~U[2026-03-15 20:00:00Z], channel_id: "ch1"
})

EventHandling.add_reminder(pid, event.id, 30)  # 30 min before
EventHandling.rsvp(pid, event.id, "user1", :going)
{:ok, due} = EventHandling.get_due_reminders(pid)
```
