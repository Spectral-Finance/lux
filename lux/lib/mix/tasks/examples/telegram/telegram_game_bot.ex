defmodule Mix.Tasks.Telegram.GameBot do
  @moduledoc """
  Mix task to run the Telegram game bot.

  ## Usage

  ```
  mix telegram.game_bot BOT_TOKEN [MAX_RUNTIME]
  ```

  Where:
  - BOT_TOKEN is your Telegram Bot API token
  - MAX_RUNTIME (optional) is the maximum runtime in seconds (default: 300 - 5 minutes)
  """

  use Mix.Task

  @shortdoc "Runs the Telegram game bot"

  @impl Mix.Task
  def run(args) do
    # Start the application
    Mix.Task.run("app.start")

    case args do
      [token | rest] ->
        # Get max_runtime if provided
        max_runtime = case rest do
          [runtime_str | _] ->
            case Integer.parse(runtime_str) do
              {runtime, _} -> runtime
              :error -> 300  # Default to 5 minutes
            end
          [] -> 300  # Default to 5 minutes
        end

        # Run the game bot with the provided token and max_runtime
        Lux.Examples.TelegramGameBot.start(token, max_runtime: max_runtime)

      [] ->
        # No token provided, show usage
        Mix.shell().error("Error: No bot token provided")
        Mix.shell().info("Usage: mix telegram.game_bot BOT_TOKEN [MAX_RUNTIME]")
        System.halt(1)
    end
  end
end
