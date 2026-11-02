# Discord Core Prisms, Lenses and Beams Integration Guide

This guide details the architecture, design principles, and operational workflows for Discord Core integration within the Lux agent framework.

---

## 1. Architecture Overview

Lux provides full compositional support for Discord server operations, structured across three core layers: **Lenses** for direct API endpoints, **Prisms** for high-level agent capabilities, and **Beams** for multi-step autonomous workflows.

```mermaid
flowchart TD
    Agent[Autonomous Agent] --> Beams[Lux.Beams.Discord\n(ModerationBeam, ChannelLifecycleBeam)]
    Agent --> Prisms[Lux.Prisms.Discord\n(MessageManagement, ChannelManagement, Moderation)]
    
    Beams --> Prisms
    Prisms --> Client[Lux.Integrations.Discord.Client\n(Req HTTP, Bot & Bearer Auth)]
    
    Agent --> Lenses[Lux.Lenses.Discord\n(Messages, Channels, Moderation)]
    Lenses --> DiscordAPI[Discord API v10]
```

---

## 2. Core Modules & Capabilities

### 2.1 Message Management (`Lux.Prisms.Discord.MessageManagementPrism`)
- **`create_message`**: Sends text and rich embed messages to channels (`POST /channels/:id/messages`).
- **`edit_message`**: Updates previously sent message contents (`PATCH /channels/:id/messages/:id`).
- **`delete_message`**: Removes individual messages by ID (`DELETE /channels/:id/messages/:id`).
- **`bulk_delete`**: Atomically deletes between 2 and 100 messages simultaneously (`POST /channels/:id/messages/bulk-delete`).
- **`get_history`**: Queries past message history with pagination limits.

### 2.2 Channel Management (`Lux.Prisms.Discord.ChannelManagementPrism`)
- **`create_channel`**: Provisions text, voice, category, or forum channels (`POST /guilds/:id/channels`).
- **`modify_channel`**: Updates channel names, topics, slowmode intervals, and thread archival status.
- **`delete_channel`**: Safely deletes or closes channels.
- **`set_permissions`**: Configures bitwise permission overwrites (`allow`, `deny`) for roles or users.
- **`list_channels`**: Retrieves full channel hierarchy in a guild.

### 2.3 Server Moderation (`Lux.Prisms.Discord.ModerationPrism`)
- **`timeout_member`**: Automatically calculates ISO8601 future timestamps and restricts member communication for a given duration (seconds).
- **`remove_timeout`**: Instantly clears timeout restrictions.
- **`ban_member`**: Bans malicious actors with customizable message purge windows (`delete_message_seconds`).
- **`unban_member`**: Lifts existing guild bans.
- **`filter_content`**: In-memory rule and keyword evaluation engine for proactive threat detection.
- **`audit_action`**: Emits immutable structured moderation audit event records.

---

## 3. Autonomous Beams

### 3.1 Moderation Beam (`Lux.Beams.Discord.ModerationBeam`)
Coordinates a complete end-to-end incident response:
1. Scans message text for prohibited terms or malicious links.
2. Deletes the offending message immediately.
3. Times out the offending member for a configurable duration.
4. Posts an audit notification to the designated staff log channel.

### 3.2 Channel Lifecycle Beam (`Lux.Beams.Discord.ChannelLifecycleBeam`)
Coordinates automated project/team channel provisioning:
1. Creates target channel with appropriate type and slowmode.
2. Sets explicit role-based permission overwrites.
3. Publishes a welcoming introductory announcement message.

---

## 4. Usage Examples

```elixir
# 1. Moderation: Time out a user for 10 minutes
{:ok, %{result: timeout}} =
  Lux.Prisms.Discord.ModerationPrism.run(%{
    action: "timeout_member",
    payload: %{
      guild_id: "123456789012345678",
      user_id: "987654321098765432",
      duration_seconds: 600
    }
  })

# 2. Bulk Delete: Purge 5 spam messages
{:ok, %{result: purge}} =
  Lux.Prisms.Discord.MessageManagementPrism.run(%{
    action: "bulk_delete",
    payload: %{
      channel_id: "123456789012345678",
      messages: ["msg_1", "msg_2", "msg_3", "msg_4", "msg_5"]
    }
  })

# 3. Channel Lifecycle Beam: Auto-provision VIP room
{:ok, result} =
  Lux.Beams.Discord.ChannelLifecycleBeam.run(%{
    guild_id: "123456789012345678",
    name: "vip-alpha",
    role_id: "111222333444555666",
    allow: "1024", # Read messages permission
    welcome_message: "Welcome VIPs! 🚀"
  })
```
