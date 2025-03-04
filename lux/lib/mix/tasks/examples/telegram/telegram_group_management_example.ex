defmodule Mix.Tasks.Telegram.GroupManagementExample do
  use Mix.Task

  @shortdoc "Run the Telegram group management example"
  @moduledoc """
  Run the Telegram group management example.

  ## Usage

  ```
  mix telegram.group_management_example CHAT_ID BOT_TOKEN [SECTION] [USER_ID]
  ```

  Where:
  - `CHAT_ID` is the ID of the chat to send messages to
  - `BOT_TOKEN` is your Telegram Bot API token
  - `SECTION` (optional) is the specific section to run (e.g., "member", "permission", "moderation")
  - `USER_ID` (optional) is the ID of a user to use for member management examples

  ## Examples

  ```
  # Run the complete example
  mix telegram.group_management_example 123456789 YOUR_BOT_TOKEN

  # Run only the member management section with a specific user
  mix telegram.group_management_example 123456789 YOUR_BOT_TOKEN member 987654321

  # Run only the permission management section
  mix telegram.group_management_example 123456789 YOUR_BOT_TOKEN permission
  ```
  """

  @impl true
  def run(args) do
    # Start the application
    Mix.Task.run("app.start")

    case args do
      [chat_id, token, section, user_id] ->
        run_section(chat_id, token, section, user_id)

      [chat_id, token, section] ->
        run_section(chat_id, token, section, nil)

      [chat_id, token] ->
        # Store the token in the application environment
        Application.put_env(:lux, :api_keys, [telegram_bot: token])
        Lux.Examples.TelegramGroupManagementExample.run(chat_id)

      _ ->
        Mix.shell().error("Usage: mix telegram.group_management_example CHAT_ID BOT_TOKEN [SECTION] [USER_ID]")
    end
  end

  defp run_section(chat_id, token, section, user_id) do
    # Store the token in the application environment
    Application.put_env(:lux, :api_keys, [telegram_bot: token])

    # Prepare options
    opts = if user_id, do: [user_id: String.to_integer(user_id)], else: []

    case section do
      "member" ->
        IO.puts("Running only the member management section...")
        if user_id do
          Lux.Examples.TelegramGroupManagementExample.demonstrate_member_management(chat_id, opts)
        else
          Mix.shell().error("USER_ID is required for member management examples")
        end

      "permission" ->
        IO.puts("Running only the permission management section...")
        Lux.Examples.TelegramGroupManagementExample.demonstrate_permission_management(chat_id)

      "moderation" ->
        IO.puts("Running only the content moderation section...")
        Lux.Examples.TelegramGroupManagementExample.demonstrate_content_moderation(chat_id)

      "spam" ->
        IO.puts("Running only the spam protection section...")
        Lux.Examples.TelegramGroupManagementExample.demonstrate_spam_protection(chat_id)

      "settings" ->
        IO.puts("Running only the group settings section...")
        Lux.Examples.TelegramGroupManagementExample.demonstrate_group_settings(chat_id)

      "channel" ->
        IO.puts("Running only the channel post management section...")
        Lux.Examples.TelegramGroupManagementExample.demonstrate_channel_post_management(chat_id)

      "admin" ->
        IO.puts("Running only the admin logging section...")
        Lux.Examples.TelegramGroupManagementExample.demonstrate_admin_logging(chat_id)

      "utility" ->
        IO.puts("Running only the utility functions section...")
        Lux.Examples.TelegramGroupManagementExample.demonstrate_utility_functions(chat_id)

      _ ->
        Mix.shell().error("Unknown section: #{section}")
        Mix.shell().info("Available sections: member, permission, moderation, spam, settings, channel, admin, utility")
    end
  end
end
