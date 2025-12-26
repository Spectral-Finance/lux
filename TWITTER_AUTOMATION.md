# Twitter Automation System

Comprehensive solution for Twitter workflow automation including scheduling, engagement rules, content management, and growth tools.

## Overview

The Twitter Automation System streamlines your social media presence through:
- **Tweet Scheduling**: Plan and auto-publish tweets and threads.
- **Auto-Reply**: Intelligent responses based on keywords or user interactions.
- **Content Calendar**: Visual management of your content pipeline.
- **Engagement Rules**: Define "if-this-then-that" logic for likes, retweets, and replies.
- **Follow Automation**: Smart follow/unfollow strategies to grow your audience.
- **DM Automation**: Welcome messages and automated response flows.

## Architecture

The system is built on 8 core components:

1. **Supervisor**: The main process that orchestrates all sub-modules and ensures system health.
2. **Storage**: Centralized database interface for persisting tweets, rules, user data, and activity logs.
3. **QueueManager**: Manages action queues (tweets, likes, follows) to strictly adhere to API rate limits.
4. **Scheduler**: Handles timing triggers for scheduled content and periodic tasks.
5. **RulesEngine**: Evaluates incoming events against defined engagement and filtering rules.
6. **ContentCalendar**: Manages the lifecycle of content from draft to scheduled to published.
7. **FollowManager**: Executes growth strategies including targeted following and cleanup (unfollowing).
8. **DMManager**: Handles direct message queues, templates, and conversation flows.

## Features

- **Scheduling**: Precision timing for single tweets, threads, and media uploads.
- **Rules Engine**: Flexible logic builder for creating automated engagement behaviors (e.g., "Like tweets from @UserX containing 'AI'").
- **Content Management**: Organize content by campaigns, tags, and status.
- **Follow/Unfollow**: Automated audience management with safety limits.
- **DM Templates**: Reusable message templates for consistent communication (Welcome DMs, FAQ replies).

## Quick Start

```javascript
const automation = require('twitter-automation');

// 1. Schedule a Tweet
await automation.schedule_tweet({
  content: "Hello World! #automation",
  time: "2023-12-01T10:00:00Z"
});

// 2. Add an Engagement Rule
await automation.add_rule({
  type: "auto_like",
  condition: { user: "@tech_influencer", keywords: ["coding", "javascript"] }
});

// 3. Enable Auto-Follow Back
await automation.auto_follow_back({
  enabled: true,
  filter_verified_only: false
});
```

## API Reference

### Supervisor
- `start()`: Initialize all subsystems.
- `status()`: Return health check of all modules.
- `shutdown()`: Gracefully stop all operations.

### Storage
- `saveTweet(tweet)`: Persist tweet data.
- `getPendingActions()`: Retrieve queued tasks.
- `logActivity(type, data)`: Record system actions for audit.

### QueueManager
- `enqueue(actionType, payload)`: Add an action to the safe queue.
- `getQueueLength(actionType)`: Check backlog size.
- `pause(actionType)`: Temporarily stop processing a specific queue.

### Scheduler
- `schedule(task, time)`: Register a one-time task.
- `addCron(jobId, cronExpression, handler)`: Register a recurring task.
- `cancel(jobId)`: Remove a scheduled task.

### RulesEngine
- `registerRule(ruleDef)`: Add a new logic rule.
- `evaluate(event)`: Process an event against all active rules.
- `enableRule(ruleId, boolean)`: Toggle a rule on or off.

### ContentCalendar
- `addToCalendar(date, content)`: Slot content for a specific date.
- `getWeeklyPlan(startDate)`: Retrieve schedule for a week.
- `moveSlot(id, newDate)`: Reschedule content.

### FollowManager
- `followUser(userId)`: Queue a follow action.
- `unfollowUser(userId)`: Queue an unfollow action.
- `getFollowersList()`: Sync current follower data.

### DMManager
- `sendDM(userId, message)`: Queue a direct message.
- `setWelcomeMessage(template)`: Configure auto-DM for new followers.
- `getInbox()`: Retrieve recent messages.

## Examples

### Content Calendar
Define a week of content in one go:
```json
[
  { "day": "Monday", "topic": "Motivation", "time": "09:00" },
  { "day": "Wednesday", "topic": "Tech Tip", "time": "14:00" },
  { "day": "Friday", "topic": "Weekly Recap", "time": "17:00" }
]
```

### Engagement Bot
Auto-reply to questions about pricing:
```javascript
RulesEngine.registerRule({
  trigger: "mention",
  contains: ["price", "cost", "how much"],
  action: "reply",
  template: "pricing_info_v1"
});
```

### Growth Strategy
Aggressive but safe growth configuration:
```javascript
FollowManager.configure({
  target_accounts: ["@competitor1", "@competitor2"],
  daily_follow_limit: 40,
  unfollow_non_followers_after_days: 7
});
```

### Campaign
Run a product launch campaign:
```javascript
const launchCampaign = new Campaign("V2 Launch");
launchCampaign.addTweets(launchSequence); // Array of scheduled threads
launchCampaign.activate();
```

### Welcome DMs
Engage new followers immediately:
```javascript
DMManager.setWelcomeMessage("Thanks for following! 🚀 Check out our docs here: [link]");
```

## Rate Limits

To ensure account safety, the system enforces the following hard limits:

- **Tweets**: 300 per 3 hours
- **Follows**: 50 per hour
- **Unfollows**: 15 per hour
- **DMs**: 15 per 15 minutes

## Integration

The Automation module integrates seamlessly with the **Analytics** module.
- Engagement actions trigger analytics events.
- Growth metrics from FollowManager are visualized in Analytics dashboards.
- Best posting times from Analytics feed into the Scheduler.
