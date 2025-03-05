defmodule Mix.Tasks.Telegram.Example do
  @moduledoc """
  Mix task to run the Telegram example.

  ## Usage

  ```
  mix telegram.example CHAT_ID BOT_TOKEN
  ```

  Where:
  - CHAT_ID is the Telegram chat ID to send messages to
  - BOT_TOKEN is your Telegram Bot API token
  """

  use Mix.Task

  @shortdoc "Runs the Telegram example"

  @impl Mix.Task
  def run(args) do
    # Start the application
    Mix.Task.run("app.start")

    case args do
      [chat_id, token | _] ->
        # Run the example with the provided chat ID and token
        Lux.Examples.TelegramExample.run(chat_id, token)

      [chat_id] ->
        # No token provided, show usage
        Mix.shell().error("Error: No bot token provided")
        Mix.shell().info("Usage: mix telegram.example CHAT_ID BOT_TOKEN")
        System.halt(1)

      [] ->
        # No chat ID or token provided, show usage
        Mix.shell().error("Error: No chat ID or bot token provided")
        Mix.shell().info("Usage: mix telegram.example CHAT_ID BOT_TOKEN")
        System.halt(1)
    end
  end
end
