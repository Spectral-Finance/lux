defmodule Mix.Tasks.Telegram.CompleteExample do
  @moduledoc """
  Mix task to run the complete Telegram example that demonstrates all features.

  ## Usage

  ```
  mix telegram.complete_example CHAT_ID BOT_TOKEN [WEBHOOK_URL]
  ```

  Where:
  - CHAT_ID is the Telegram chat ID to send messages to
  - BOT_TOKEN is your Telegram Bot API token
  - WEBHOOK_URL (optional) is the URL for webhook examples

  ## Examples

  ```bash
  # Run without webhook examples
  mix telegram.complete_example "YOUR_CHAT_ID" "YOUR_BOT_TOKEN"

  # Run with webhook examples
  mix telegram.complete_example "YOUR_CHAT_ID" "YOUR_BOT_TOKEN" "https://your-domain.com/webhook"
  ```
  """

  use Mix.Task

  @shortdoc "Runs the complete Telegram example"

  @impl Mix.Task
  def run(args) do
    # Start the application
    Mix.Task.run("app.start")

    case args do
      [chat_id, token | rest] ->
        # Get webhook URL if provided
        webhook_url = List.first(rest)
        skip_webhook = webhook_url == nil

        # Run the example with the provided parameters
        Lux.Examples.TelegramCompleteExample.run(chat_id, token,
          webhook_url: webhook_url,
          skip_webhook: skip_webhook
        )

      [chat_id] ->
        # No token provided, show usage
        Mix.shell().error("Error: No bot token provided")
        Mix.shell().info("Usage: mix telegram.complete_example CHAT_ID BOT_TOKEN [WEBHOOK_URL]")
        System.halt(1)

      [] ->
        # No chat ID or token provided, show usage
        Mix.shell().error("Error: No chat ID or bot token provided")
        Mix.shell().info("Usage: mix telegram.complete_example CHAT_ID BOT_TOKEN [WEBHOOK_URL]")
        System.halt(1)
    end
  end
end
