defmodule Mix.Tasks.Telegram.WebhookEchoBot do
  @moduledoc """
  Mix task to run the Telegram webhook echo bot.

  ## Usage

  ```
  mix telegram.webhook_echo_bot [BOT_TOKEN] [MAX_RUNTIME] [PORT]
  ```

  Where:
  - BOT_TOKEN is your Telegram Bot API token
  - MAX_RUNTIME (optional) is the maximum runtime in seconds (default: 300 - 5 minutes)
  - PORT (optional) is the port to run the webhook server on (default: 4000)
  """

  use Mix.Task

  @shortdoc "Runs the Telegram webhook echo bot"

  @impl Mix.Task
  def run(args) do
    # Start the application
    Mix.Task.run("app.start")

    case args do
      [token | rest] ->
        # Get max_runtime if provided
        {max_runtime, rest2} = case rest do
          [runtime_str | rest2] ->
            case Integer.parse(runtime_str) do
              {runtime, _} -> {runtime, rest2}
              :error -> {300, rest2}  # Default to 5 minutes
            end
          [] -> {300, []}  # Default to 5 minutes
        end

        # Get port if provided
        port = case rest2 do
          [port_str | _] ->
            case Integer.parse(port_str) do
              {port, _} -> port
              :error -> 4000  # Default to port 4000
            end
          [] -> 4000  # Default to port 4000
        end

        # Run the webhook echo bot with the provided token, max_runtime, and port
        Lux.Examples.Telegram.WebhookEchoBot.start(token, max_runtime: max_runtime, port: port)

      [] ->
        # No token provided, show usage
        Mix.shell().error("Error: No bot token provided")
        Mix.shell().info("Usage: mix telegram.webhook_echo_bot BOT_TOKEN [MAX_RUNTIME] [PORT]")
        System.halt(1)
    end
  end
end
