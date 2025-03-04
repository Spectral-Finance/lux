defmodule Mix.Tasks.Telegram.CompleteExample do
  use Mix.Task

  @shortdoc "Run the Telegram complete example"
  @moduledoc """
  Run the Telegram complete example.

  ## Usage

  ```
  mix telegram.complete_example CHAT_ID BOT_TOKEN [SECTION]
  ```

  Where:
  - `CHAT_ID` is the ID of the chat to send messages to
  - `BOT_TOKEN` is your Telegram Bot API token
  - `SECTION` (optional) is the specific section to run (e.g., "polls", "stickers", "game")

  ## Examples

  ```
  # Run the complete example
  mix telegram.complete_example 123456789 YOUR_BOT_TOKEN

  # Run only the polls section
  mix telegram.complete_example 123456789 YOUR_BOT_TOKEN polls
  ```
  """

  @impl true
  def run(args) do
    # Start the application
    Mix.Task.run("app.start")

    case args do
      [chat_id, token, section] ->
        run_section(chat_id, token, section)

      [chat_id, token] ->
        Lux.Examples.TelegramCompleteExample.run(chat_id, token)

      _ ->
        Mix.shell().error("Usage: mix telegram.complete_example CHAT_ID BOT_TOKEN [SECTION]")
    end
  end

  defp run_section(chat_id, token, section) do
    # Store the token in the application environment
    Application.put_env(:lux, :api_keys, [telegram_bot: token])

    case section do
      "polls" ->
        IO.puts("Running only the polls section...")
        Lux.Examples.TelegramCompleteExample.demonstrate_polls_and_quizzes(chat_id)

      "stickers" ->
        IO.puts("Running only the stickers section...")
        Lux.Examples.TelegramCompleteExample.demonstrate_sticker_features(chat_id)

      "game" ->
        IO.puts("Running only the game section...")
        Lux.Examples.TelegramCompleteExample.demonstrate_game_features(chat_id)

      "live_location" ->
        IO.puts("Running only the live location section...")
        Lux.Examples.TelegramCompleteExample.demonstrate_live_location(chat_id)

      "interactive" ->
        IO.puts("Running only the interactive elements section...")
        Lux.Examples.TelegramCompleteExample.demonstrate_interactive_elements(chat_id)

      _ ->
        Mix.shell().error("Unknown section: #{section}")
        Mix.shell().info("Available sections: polls, stickers, game, live_location, interactive")
    end
  end
end
