# Lux Telegram Bot Examples

This document provides instructions for running the various Telegram bot examples included in the Lux project.

## Prerequisites

Before running any of the Telegram bots, you'll need:

1. A Telegram Bot API token (obtained from [@BotFather](https://t.me/BotFather))
2. Docker with the Lux development environment running
3. For webhook examples: [ngrok](https://ngrok.com/) installed and available in your PATH

## Available Telegram Bot Examples

The Lux project includes several Telegram bot examples:

1. **Echo Bot** - A simple bot that echoes back messages (polling mode)
2. **Webhook Echo Bot** - An echo bot that uses webhooks instead of polling
3. **Game Bot** - A bot that demonstrates Telegram's game platform
4. **Example Bot** - A basic template for creating new bots
5. **Group Management Bot** - A comprehensive example demonstrating group and channel management features

## Running the Examples

### 1. Echo Bot (Polling Mode)

This is the simplest bot to run. It uses polling to receive updates from Telegram.

```bash
docker exec -it lux_dev bash -c "cd /workspace/lux/lux && mix telegram.echo_bot YOUR_BOT_TOKEN"
```

Replace `YOUR_BOT_TOKEN` with your actual Telegram Bot API token.

### 2. Webhook Echo Bot

This bot uses webhooks instead of polling. It requires ngrok to expose your local server to the internet.

```bash
docker exec -it lux_dev bash -c "cd /workspace/lux/lux && mix telegram.webhook_fixed YOUR_BOT_TOKEN MAX_RUNTIME PORT"
```

Parameters:
- `YOUR_BOT_TOKEN`: Your Telegram Bot API token
- `MAX_RUNTIME`: Maximum runtime in seconds (e.g., 300 for 5 minutes)
- `PORT`: The local port to run the server on (e.g., 4000)

Example:
```bash
docker exec -it lux_dev bash -c "cd /workspace/lux/lux && mix telegram.webhook_fixed YOUR_BOT_TOKEN 300 4000"
```

### 3. Game Bot

This bot demonstrates Telegram's game platform features.

```bash
docker exec -it lux_dev bash -c "cd /workspace/lux/lux && mix telegram.game_bot YOUR_BOT_TOKEN"
```

### 4. Example Bot

A basic template for creating new bots.

```bash
docker exec -it lux_dev bash -c "cd /workspace/lux/lux && mix telegram.example YOUR_BOT_TOKEN"
```

### 5. Group Management Bot

A comprehensive example demonstrating Telegram's group and channel management features.

```bash
docker exec -it lux_dev bash -c "cd /workspace/lux/lux && mix telegram.group_management_example CHAT_ID YOUR_BOT_TOKEN"
```

Parameters:
- `CHAT_ID`: Unique identifier for the target chat
- `YOUR_BOT_TOKEN`: Your Telegram Bot API token

You can also run specific sections of the example:

```bash
docker exec -it lux_dev bash -c "cd /workspace/lux/lux && mix telegram.group_management_example CHAT_ID YOUR_BOT_TOKEN SECTION [USER_ID]"
```

Where `SECTION` can be one of:
- `member` - Member management features (requires USER_ID)
- `permission` - Permission management features
- `moderation` - Content moderation features
- `spam` - Spam protection features
- `settings` - Group settings management
- `channel` - Channel post management
- `admin` - Admin action logging
- `utility` - Utility functions

Example:
```bash
docker exec -it lux_dev bash -c "cd /workspace/lux/lux && mix telegram.group_management_example 123456789 YOUR_BOT_TOKEN permission"
```

## Troubleshooting

### Webhook Issues

If you encounter issues with webhooks (such as conflicts between polling and webhook modes), you can delete the current webhook:

```bash
docker exec -it lux_dev bash -c "cd /workspace/lux/lux && mix telegram.delete_webhook YOUR_BOT_TOKEN"
```

This is particularly useful when you see errors like:
```
Error fetching updates: %{"description" => "Conflict: can't use getUpdates method while webhook is active; use deleteWebhook to delete the webhook first", "error_code" => 409, "ok" => false}
```

### Common Issues

1. **Bot not responding**: Make sure your token is correct and the bot is running.
2. **Webhook errors**: Ensure ngrok is running and the URL is correctly set.
3. **Application crashes**: Check the logs for error messages.
4. **Permission errors**: For group management features, ensure your bot has the necessary admin privileges in the group.

## Webhook vs. Polling

- **Polling**: The bot repeatedly asks Telegram for updates. Simpler to set up but less efficient.
- **Webhooks**: Telegram sends updates to your server as they happen. More efficient but requires a publicly accessible server (which is why we use ngrok).

## Stopping the Bots

- For polling bots: Press `Ctrl+C` to stop the bot.
- For webhook bots: Press `Ctrl+C` to stop the bot. The script will automatically clean up resources, including deleting the webhook and stopping ngrok.

## Creating Your Own Bot

You can use these examples as a starting point for creating your own Telegram bots. The `telegram_example.ex` file provides a basic template that you can modify.

## Additional Resources

- [Telegram Bot API Documentation](https://core.telegram.org/bots/api)
- [Lux Documentation](https://hexdocs.pm/lux)
- [ngrok Documentation](https://ngrok.com/docs) 