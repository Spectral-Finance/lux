defmodule Lux.Examples.TelegramEchoBot do
  @moduledoc """
  A simple Telegram echo bot that listens for messages and echoes them back to the sender.

  This example demonstrates how to use the TelegramBotLens module to:
  1. Receive messages using long polling
  2. Process incoming messages
  3. Send responses back to users
  """

  alias Lux.Lenses.Telegram.Client

  @doc """
  Starts the echo bot with the specified token.

  ## Parameters

  - `token`: Your Telegram Bot API token
  - `opts`: Additional options for the bot
    - `:timeout`: Polling timeout in seconds (default: 30)
    - `:limit`: Maximum number of updates to fetch at once (default: 10)
    - `:allowed_updates`: Types of updates to receive (default: ["message"])
    - `:max_runtime`: Maximum runtime in seconds (default: 300 - 5 minutes)

  ## Example

  ```elixir
  # Start the echo bot with your token
  Lux.Examples.TelegramEchoBot.start("YOUR_BOT_TOKEN")

  # Start with custom options
  Lux.Examples.TelegramEchoBot.start("YOUR_BOT_TOKEN", timeout: 60, max_runtime: 600)
  ```
  """
  def start(token, opts \\ []) do
    # Default options
    timeout = Keyword.get(opts, :timeout, 30)
    limit = Keyword.get(opts, :limit, 10)
    allowed_updates = Keyword.get(opts, :allowed_updates, ["message"])
    max_runtime = Keyword.get(opts, :max_runtime, 300)

    IO.puts("Starting Telegram Echo Bot...")
    IO.puts("Press Ctrl+C to stop the bot")
    IO.puts("Bot will automatically stop after #{max_runtime} seconds")
    IO.puts("Waiting for messages...")

    # Start time for max runtime calculation
    start_time = System.monotonic_time(:second)

    # Start polling loop with initial offset of 0
    polling_loop(token, 0, timeout, limit, allowed_updates, start_time, max_runtime)
  end

  # Main polling loop
  defp polling_loop(token, offset, timeout, limit, allowed_updates, start_time, max_runtime) do
    # Check if we've exceeded the maximum runtime
    current_time = System.monotonic_time(:second)
    elapsed_time = current_time - start_time

    if elapsed_time >= max_runtime do
      IO.puts("\nMaximum runtime of #{max_runtime} seconds reached. Stopping bot.")
    else
      # Fetch updates from Telegram
      params = %{
        method: "getUpdates",
        offset: offset,
        timeout: timeout,
        limit: limit,
        allowed_updates: allowed_updates,
        token: token
      }

      url = "https://api.telegram.org/bot#{token}/getUpdates"

      lens = %{
        url: url,
        method: :post,
        headers: [{"content-type", "application/json"}],
        params: Map.drop(params, [:url, :method, :token])
      }

      case Client.make_request(lens, lens.params) do
        {:ok, updates} when is_list(updates) and length(updates) > 0 ->
          # Process each update
          new_offset = process_updates(updates, token)

          # Continue polling with new offset
          polling_loop(token, new_offset, timeout, limit, allowed_updates, start_time, max_runtime)

        {:ok, _} ->
          # No updates, continue polling with same offset
          polling_loop(token, offset, timeout, limit, allowed_updates, start_time, max_runtime)

        {:error, error} ->
          IO.puts("Error fetching updates: #{inspect(error)}")
          # Wait a bit before retrying
          :timer.sleep(5000)
          polling_loop(token, offset, timeout, limit, allowed_updates, start_time, max_runtime)
      end
    end
  end

  # Process updates and return the new offset
  defp process_updates(updates, token) do
    # Find the highest update_id to use as the new offset
    new_offset = updates
      |> Enum.map(fn update -> update["update_id"] end)
      |> Enum.max()
      |> Kernel.+(1)  # Add 1 to get the next update

    # Process each update
    Enum.each(updates, fn update -> handle_update(update, token) end)

    # Return the new offset
    new_offset
  end

  # Handle a single update
  defp handle_update(update, token) do
    # Check if this is a message update
    if Map.has_key?(update, "message") do
      message = update["message"]

      # Check if the message has text
      if Map.has_key?(message, "text") do
        # Get message details
        chat_id = message["chat"]["id"]
        message_id = message["message_id"]
        text = message["text"]
        from_user = get_user_name(message["from"])

        IO.puts("\nReceived message from #{from_user}: #{text}")

        # Echo the message back
        echo_text = "Echo: #{text}"
        send_message(chat_id, echo_text, message_id, token)
      end
    end
  end

  # Get a user's name (first name + last name if available)
  defp get_user_name(user) do
    first_name = user["first_name"] || ""
    last_name = user["last_name"] || ""

    if last_name != "" do
      "#{first_name} #{last_name}"
    else
      first_name
    end
  end

  # Send a message in reply to another message
  defp send_message(chat_id, text, reply_to_message_id, token) do
    params = %{
      method: "sendMessage",
      chat_id: chat_id,
      text: text,
      reply_to_message_id: reply_to_message_id,
      token: token
    }

    url = "https://api.telegram.org/bot#{token}/sendMessage"

    lens = %{
      url: url,
      method: :post,
      headers: [{"content-type", "application/json"}],
      params: Map.drop(params, [:url, :method, :token])
    }

    case Client.make_request(lens, lens.params) do
      {:ok, response} ->
        IO.puts("Sent echo reply with message ID: #{response["message_id"]}")

      {:error, error} ->
        IO.puts("Error sending echo reply: #{inspect(error)}")
    end
  end
end
