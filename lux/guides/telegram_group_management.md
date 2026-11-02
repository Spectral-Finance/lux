# Telegram Group and Channel Management in Lux

## Overview

The `Lux.Integrations.Telegram.GroupManagement` module provides comprehensive administration, moderation, and governance capabilities for Telegram groups, supergroups, and channels. It supports:

- **Member Management**: Granular ban, unban, restriction (mute/media restriction), and administrator promotion.
- **Permission Management**: Full implementation of Telegram `ChatPermissions` with preset configurations (`read_only`, `text_only`, `media_restricted`, `standard`, `moderator`).
- **Content Moderation & Spam Protection**: Automated keyword blacklist scanning, unauthorized invite link detection, mass mention protection, and forward spam filtering.
- **Group Settings Administration**: Chat title/description updates, slow mode delays (0 to 21,600s), primary and secondary invite link creation/revocation, and membership join request approvals.
- **Channel Post & Pinned Messages**: Silent or loud message pinning, unpinning, and linked discussion chat detection.
- **Audit Logging System**: Structured administrative event logging with ready-to-dispatch HTML and Markdown notifications for admin channels or forum topics.
- **Prisms & Beams**: 9 dedicated Prisms and the automated `Lux.Beams.Telegram.GroupModerationBeam` pipeline.

---

## Architecture

```
                       +---------------------------------------+
                       |        Telegram Group / Channel       |
                       +---------------------------------------+
                                           |
                                           v
                       +---------------------------------------+
                       |      GroupModerationBeam Pipeline     |
                       +---------------------------------------+
                                           |
        +----------------------------------+----------------------------------+
        |                                  |                                  |
        v                                  v                                  v
+------------------+             +--------------------+            +--------------------+
|  MemberManager   |             | PermissionManager  |            | ContentModerator   |
| - Ban / Unban    |             | - ChatPermissions  |            | - Banned keywords  |
| - Restrict / Mute|             | - Standard presets |            | - Spam link filter |
| - Promote admins |             | - Rights check     |            | - Mass mentions    |
+------------------+             +--------------------+            +--------------------+
        |                                  |                                  |
        +----------------------------------+----------------------------------+
                                           |
        +----------------------------------+----------------------------------+
        |                                                                     |
        v                                                                     v
+------------------+                                                +--------------------+
| SettingsManager  |                                                |   AuditLogger      |
| - Slow mode      |                                                | - Structured log   |
| - Invite links   |                                                | - Admin alerts     |
| - Join requests  |                                                | - Event filtering  |
+------------------+                                                +--------------------+
```

---

## 1. Member Management

### Banning & Unbanning

```elixir
alias Lux.Integrations.Telegram.GroupManagement.MemberManager

# Ban member permanently and revoke previous messages:
{:ok, _} = MemberManager.ban_member(chat_id, user_id, revoke_messages: true)

# Temporary ban for 24 hours:
until = System.system_time(:second) + 86400
{:ok, _} = MemberManager.ban_member(chat_id, user_id, until_date: until)

# Unban member:
{:ok, _} = MemberManager.unban_member(chat_id, user_id, only_if_banned: true)
```

### Restricting & Muting

```elixir
alias Lux.Integrations.Telegram.GroupManagement.PermissionManager

# Restrict user to read-only for 1 hour:
{:ok, read_only} = PermissionManager.get_preset(:read_only)
until = System.system_time(:second) + 3600
{:ok, _} = MemberManager.restrict_member(chat_id, user_id, read_only, until_date: until)
```

### Promoting Administrators

```elixir
privileges = %{
  can_manage_chat: true,
  can_delete_messages: true,
  can_restrict_members: true,
  can_pin_messages: true
}

{:ok, _} = MemberManager.promote_member(chat_id, user_id, privileges)
{:ok, _} = MemberManager.set_admin_title(chat_id, user_id, "Chief Moderator")
```

---

## 2. Permission Presets

`PermissionManager` provides validated presets for common community tiers:

| Preset | Allowed Rights | Typical Use Case |
|---|---|---|
| `:read_only` | None | Temporary mute for offending members |
| `:text_only` | `can_send_messages`, `can_invite_users` | High-security mode during token launches / airdrops |
| `:media_restricted` | `can_send_messages`, `can_send_polls`, `can_invite_users` | Prevents sticker, image, and link spam |
| `:standard` | Text, audio, docs, photos, videos, voice, polls, previews | Normal verified community members |
| `:moderator` | Standard + `can_pin_messages`, `can_manage_topics`, `can_change_info` | Community moderators |

```elixir
# Update entire supergroup to media-restricted:
{:ok, media_rest} = PermissionManager.get_preset(:media_restricted)
{:ok, _} = PermissionManager.set_chat_permissions(chat_id, media_rest)
```

---

## 3. Automated Content Moderation & Anti-Spam

The `ContentModerator` detects violations and suggests/executes actions:

```elixir
alias Lux.Integrations.Telegram.GroupManagement.ContentModerator

custom_config = %{
  banned_words: ["free airdrop", "connect wallet", "giveaway 100x"],
  allow_telegram_links: false,
  max_mentions: 5
}

{:ok, evaluation} = ContentModerator.check_content(message, custom_config)

case evaluation.recommended_action do
  :delete_and_warn ->
    ContentModerator.enforce_action(chat_id, message_id, user_id, :delete_and_warn)

  :delete_and_mute ->
    ContentModerator.enforce_action(chat_id, message_id, user_id, :delete_and_mute, mute_duration_seconds: 7200)

  :none ->
    :ok
end
```

---

## 4. Group & Channel Settings

### Slow Mode & Invite Links

```elixir
alias Lux.Integrations.Telegram.GroupManagement.SettingsManager

# Set slow mode to 30 seconds delay between messages:
{:ok, _} = SettingsManager.set_slow_mode(chat_id, 30)

# Create an invite link limited to 100 members with join requests:
{:ok, res} = SettingsManager.create_invite_link(chat_id,
  name: "Affiliate Campaign Q4",
  member_limit: 100,
  creates_join_request: true
)
invite_url = res["result"]["invite_link"]

# Approve a join request:
{:ok, _} = SettingsManager.approve_join_request(chat_id, candidate_user_id)
```

---

## 5. Pinned Messages & Channel Posts

```elixir
alias Lux.Integrations.Telegram.GroupManagement.ChannelPostManager

# Pin an announcement silently without pushing push notifications to users:
{:ok, _} = ChannelPostManager.pin_message(chat_id, announcement_msg_id, disable_notification: true)

# Unpin a message:
{:ok, _} = ChannelPostManager.unpin_message(chat_id, message_id: announcement_msg_id)
```

---

## 6. Audit Logging System

`AuditLogger` generates immutable records and formats log messages for transmission to an administrator channel:

```elixir
alias Lux.Integrations.Telegram.GroupManagement.AuditLogger

entry = AuditLogger.create_entry(:ban, chat_id,
  actor_id: admin_id,
  target_id: spammer_id,
  reason: "Mass mention phishing attack"
)

# Render formatted alert for Telegram:
html_message = AuditLogger.format_log_message(entry, :html)

# Send to admin log channel:
Lux.Prisms.Telegram.Messages.SendMessage.handler(%{
  chat_id: admin_log_channel_id,
  text: html_message,
  parse_mode: "HTML"
}, %{})
```

---

## 7. Prisms Reference

| Prism | Module | Purpose |
|---|---|---|
| `BanMember` | `Lux.Prisms.Telegram.GroupManagement.BanMember` | Bans user with message revocation and until_date |
| `UnbanMember` | `Lux.Prisms.Telegram.GroupManagement.UnbanMember` | Unbans previously removed member |
| `RestrictMember` | `Lux.Prisms.Telegram.GroupManagement.RestrictMember` | Applies presets or custom ChatPermissions |
| `PromoteMember` | `Lux.Prisms.Telegram.GroupManagement.PromoteMember` | Grants administrative rights and sets custom titles |
| `SetChatPermissions` | `Lux.Prisms.Telegram.GroupManagement.SetChatPermissions` | Updates default supergroup permissions |
| `ModerateContent` | `Lux.Prisms.Telegram.GroupManagement.ModerateContent` | Scans text for violations and executes enforcement |
| `ManageInviteLink` | `Lux.Prisms.Telegram.GroupManagement.ManageInviteLink` | Creates, edits, or revokes invite links |
| `ManagePinnedMessage` | `Lux.Prisms.Telegram.GroupManagement.ManagePinnedMessage` | Pins/unpins messages with silent flags |
| `LogAdminAction` | `Lux.Prisms.Telegram.GroupManagement.LogAdminAction` | Logs moderation events and generates channel alerts |

---

## 8. GroupModerationBeam Pipeline

Automates the entire detection-enforcement-logging loop:

```elixir
alias Lux.Beams.Telegram.GroupModerationBeam

# Ingest and moderate incoming message:
{:ok, result} = GroupModerationBeam.moderate_message(chat_id, incoming_message, execute_action: true)

result.moderation.violation #=> "banned_word"
result.moderation.action    #=> "delete_and_warn"
result.moderation.executed  #=> true
result.audit_log.id         #=> "audit_1700000000_12345"
```
