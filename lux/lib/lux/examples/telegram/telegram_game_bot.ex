defmodule Lux.Examples.TelegramGameBot do
  @moduledoc """
  A Telegram game bot that implements a simple number guessing game.

  This example demonstrates how to use the TelegramBotLens module to:
  1. Create and use inline keyboards
  2. Handle callback queries from button presses
  3. Update messages with new content and keyboards
  4. Implement a simple game flow
  """

  alias Lux.Lenses.Telegram.Client

  # Game state constants
  @max_number 100
  @max_attempts 7

  @doc """
  Starts the game bot with the specified token.

  ## Parameters

  - `token`: Your Telegram Bot API token
  - `opts`: Additional options for the bot
    - `:timeout`: Polling timeout in seconds (default: 30)
    - `:limit`: Maximum number of updates to fetch at once (default: 10)
    - `:allowed_updates`: Types of updates to receive (default: ["message", "callback_query"])
    - `:max_runtime`: Maximum runtime in seconds (default: 300 - 5 minutes)

  ## Example

  ```elixir
  # Start the game bot with your token
  Lux.Examples.TelegramGameBot.start("YOUR_BOT_TOKEN")

  # Start with custom options
  Lux.Examples.TelegramGameBot.start("YOUR_BOT_TOKEN", timeout: 60, max_runtime: 600)
  ```
  """
  def start(token, opts \\ []) do
    # Default options
    timeout = Keyword.get(opts, :timeout, 30)
    limit = Keyword.get(opts, :limit, 10)
    allowed_updates = Keyword.get(opts, :allowed_updates, ["message", "callback_query"])
    max_runtime = Keyword.get(opts, :max_runtime, 300)

    IO.puts("Starting Telegram Game Bot...")
    IO.puts("Press Ctrl+C to stop the bot")
    IO.puts("Bot will automatically stop after #{max_runtime} seconds")
    IO.puts("Send /start to begin the game")

    # Initialize the game state
    game_state = %{}

    # Start time for max runtime calculation
    start_time = System.monotonic_time(:second)

    # Start polling loop with initial offset of 0
    polling_loop(token, 0, timeout, limit, allowed_updates, start_time, max_runtime, game_state)
  end

  # Main polling loop
  defp polling_loop(token, offset, timeout, limit, allowed_updates, start_time, max_runtime, game_state) do
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
          # Process each update and get the new game state
          {new_offset, new_game_state} = process_updates(updates, token, game_state)

          # Continue polling with new offset and game state
          polling_loop(token, new_offset, timeout, limit, allowed_updates, start_time, max_runtime, new_game_state)

        {:ok, _} ->
          # No updates, continue polling with same offset and game state
          polling_loop(token, offset, timeout, limit, allowed_updates, start_time, max_runtime, game_state)

        {:error, error} ->
          IO.puts("Error fetching updates: #{inspect(error)}")
          # Wait a bit before retrying
          :timer.sleep(5000)
          polling_loop(token, offset, timeout, limit, allowed_updates, start_time, max_runtime, game_state)
      end
    end
  end

  # Process updates and return the new offset and game state
  defp process_updates(updates, token, game_state) do
    # Find the highest update_id to use as the new offset
    new_offset = updates
      |> Enum.map(fn update -> update["update_id"] end)
      |> Enum.max()
      |> Kernel.+(1)  # Add 1 to get the next update

    # Process each update and accumulate the new game state
    new_game_state = Enum.reduce(updates, game_state, fn update, acc_state ->
      handle_update(update, token, acc_state)
    end)

    # Return the new offset and game state
    {new_offset, new_game_state}
  end

  # Handle a single update
  defp handle_update(update, token, game_state) do
    cond do
      # Handle message updates
      Map.has_key?(update, "message") ->
        handle_message(update["message"], token, game_state)

      # Handle callback query updates (button presses)
      Map.has_key?(update, "callback_query") ->
        handle_callback_query(update["callback_query"], token, game_state)

      # Ignore other types of updates
      true ->
        game_state
    end
  end

  # Handle a message update
  defp handle_message(message, token, game_state) do
    # Check if the message has text
    if Map.has_key?(message, "text") do
      chat_id = message["chat"]["id"]
      text = message["text"]
      from_user = get_user_name(message["from"])
      user_id = message["from"]["id"]

      IO.puts("\nReceived message from #{from_user}: #{text}")

      # Handle commands
      case text do
        "/start" ->
          start_game(chat_id, user_id, from_user, token, game_state)

        "/help" ->
          send_help(chat_id, token)
          game_state

        "/stop" ->
          stop_game(chat_id, user_id, token, game_state)

        _ ->
          # Ignore other messages
          game_state
      end
    else
      # Ignore non-text messages
      game_state
    end
  end

  # Handle a callback query update (button press)
  defp handle_callback_query(callback_query, token, game_state) do
    query_id = callback_query["id"]
    user_id = callback_query["from"]["id"]
    chat_id = callback_query["message"]["chat"]["id"]
    message_id = callback_query["message"]["message_id"]
    data = callback_query["data"]
    from_user = get_user_name(callback_query["from"])

    IO.puts("\nReceived callback query from #{from_user}: #{data}")

    # Answer the callback query to stop the loading indicator
    answer_callback_query(query_id, token)

    # Process the button press based on the data
    cond do
      # Handle number guesses
      String.starts_with?(data, "guess_") ->
        guess = String.replace(data, "guess_", "") |> String.to_integer()
        handle_guess(chat_id, message_id, user_id, guess, token, game_state)

      # Handle range selections
      String.starts_with?(data, "range_") ->
        range_data = String.replace(data, "range_", "")
        [min_str, max_str] = String.split(range_data, "_")
        min = String.to_integer(min_str)
        max = String.to_integer(max_str)
        handle_range_selection(chat_id, message_id, user_id, min, max, token, game_state)

      # Handle new game request
      data == "new_game" ->
        start_game(chat_id, user_id, from_user, token, game_state)

      # Ignore other callback data
      true ->
        game_state
    end
  end

  # Start a new game for a user
  defp start_game(chat_id, user_id, user_name, token, game_state) do
    # Generate a random number for the user to guess
    target_number = :rand.uniform(@max_number)

    # Create a new game for the user
    user_game = %{
      target_number: target_number,
      attempts: 0,
      min: 1,
      max: @max_number,
      chat_id: chat_id,
      message_id: nil
    }

    # Update the game state with the new game
    new_game_state = Map.put(game_state, user_id, user_game)

    IO.puts("\nStarting new game for #{user_name}. Target number: #{target_number}")

    # Send the initial game message with the range selection keyboard
    message = """
    🎮 *Number Guessing Game* 🎮

    I'm thinking of a number between 1 and #{@max_number}.
    You have #{@max_attempts} attempts to guess it.

    First, select a range to narrow down your search:
    """

    # Create a keyboard with range options
    keyboard = create_range_keyboard(1, @max_number)

    # Send the message with the keyboard
    result = send_message_with_keyboard(chat_id, message, keyboard, token)

    case result do
      {:ok, response} ->
        # Update the game state with the message ID
        message_id = response["message_id"]
        user_game = Map.put(user_game, :message_id, message_id)
        Map.put(new_game_state, user_id, user_game)

      {:error, _} ->
        # If there was an error, just return the new game state without the message ID
        new_game_state
    end
  end

  # Send help information
  defp send_help(chat_id, token) do
    message = """
    🎮 *Number Guessing Game Help* 🎮

    Commands:
    /start - Start a new game
    /help - Show this help message
    /stop - Stop the current game

    How to play:
    1. I'll think of a number between 1 and #{@max_number}
    2. You have #{@max_attempts} attempts to guess it
    3. First, select a range to narrow down your search
    4. Then, make specific guesses
    5. I'll tell you if your guess is too high or too low
    6. Try to guess the number in as few attempts as possible!
    """

    send_message(chat_id, message, token, parse_mode: "Markdown")
  end

  # Stop the current game for a user
  defp stop_game(chat_id, user_id, token, game_state) do
    # Check if the user has an active game
    if Map.has_key?(game_state, user_id) do
      user_game = game_state[user_id]

      message = """
      Game stopped. The number I was thinking of was #{user_game.target_number}.

      Send /start to play again!
      """

      send_message(chat_id, message, token)

      # Remove the user's game from the game state
      Map.delete(game_state, user_id)
    else
      send_message(chat_id, "You don't have an active game. Send /start to play!", token)
      game_state
    end
  end

  # Handle a range selection
  defp handle_range_selection(chat_id, message_id, user_id, min, max, token, game_state) do
    # Check if the user has an active game
    if Map.has_key?(game_state, user_id) do
      user_game = game_state[user_id]
      target = user_game.target_number

      # Check if the target is in the selected range
      if target >= min && target <= max do
        # Update the user's game with the new range
        user_game = %{user_game | min: min, max: max}

        # Create a message with the new range
        message = """
        🎮 *Number Guessing Game* 🎮

        I'm thinking of a number between #{min} and #{max}.
        You have #{@max_attempts - user_game.attempts} attempts remaining.

        Make your guess:
        """

        # Create a keyboard with number buttons
        keyboard = create_number_keyboard(min, max)

        # Update the message with the new keyboard
        edit_message_with_keyboard(chat_id, message_id, message, keyboard, token)

        # Update the game state
        Map.put(game_state, user_id, user_game)
      else
        # The target is not in the selected range
        message = """
        🎮 *Number Guessing Game* 🎮

        The number is NOT in the range #{min}-#{max}.
        You have #{@max_attempts - user_game.attempts} attempts remaining.

        Try a different range:
        """

        # Create a keyboard with new range options
        keyboard = create_range_keyboard(1, @max_number)

        # Update the message with the new keyboard
        edit_message_with_keyboard(chat_id, message_id, message, keyboard, token)

        # Increment the attempts
        user_game = %{user_game | attempts: user_game.attempts + 1}

        # Check if the user has used all their attempts
        if user_game.attempts >= @max_attempts do
          handle_game_over(chat_id, message_id, user_id, token, game_state)
        else
          # Update the game state
          Map.put(game_state, user_id, user_game)
        end
      end
    else
      # User doesn't have an active game
      edit_message(chat_id, message_id, "You don't have an active game. Send /start to play!", token)
      game_state
    end
  end

  # Handle a number guess
  defp handle_guess(chat_id, message_id, user_id, guess, token, game_state) do
    # Check if the user has an active game
    if Map.has_key?(game_state, user_id) do
      user_game = game_state[user_id]
      target = user_game.target_number

      # Increment the attempts
      user_game = %{user_game | attempts: user_game.attempts + 1}
      attempts_used = user_game.attempts
      attempts_left = @max_attempts - attempts_used

      cond do
        # Correct guess
        guess == target ->
          message = """
          🎉 *Congratulations!* 🎉

          You guessed the number #{target} correctly in #{attempts_used} attempts!

          Want to play again?
          """

          # Create a keyboard with a new game button
          keyboard = %{
            "inline_keyboard" => [
              [%{"text" => "Play Again", "callback_data" => "new_game"}]
            ]
          }

          # Update the message with the new keyboard
          edit_message_with_keyboard(chat_id, message_id, message, keyboard, token)

          # Remove the user's game from the game state
          Map.delete(game_state, user_id)

        # Out of attempts
        attempts_left <= 0 ->
          handle_game_over(chat_id, message_id, user_id, token, game_state)

        # Guess is too low
        guess < target ->
          # Update the min value
          user_game = %{user_game | min: max(user_game.min, guess + 1)}

          message = """
          Your guess #{guess} is too low.
          The number is between #{user_game.min} and #{user_game.max}.
          You have #{attempts_left} attempts remaining.

          Make your next guess:
          """

          # Create a keyboard with updated number buttons
          keyboard = create_number_keyboard(user_game.min, user_game.max)

          # Update the message with the new keyboard
          edit_message_with_keyboard(chat_id, message_id, message, keyboard, token)

          # Update the game state
          Map.put(game_state, user_id, user_game)

        # Guess is too high
        guess > target ->
          # Update the max value
          user_game = %{user_game | max: min(user_game.max, guess - 1)}

          message = """
          Your guess #{guess} is too high.
          The number is between #{user_game.min} and #{user_game.max}.
          You have #{attempts_left} attempts remaining.

          Make your next guess:
          """

          # Create a keyboard with updated number buttons
          keyboard = create_number_keyboard(user_game.min, user_game.max)

          # Update the message with the new keyboard
          edit_message_with_keyboard(chat_id, message_id, message, keyboard, token)

          # Update the game state
          Map.put(game_state, user_id, user_game)
      end
    else
      # User doesn't have an active game
      edit_message(chat_id, message_id, "You don't have an active game. Send /start to play!", token)
      game_state
    end
  end

  # Handle game over
  defp handle_game_over(chat_id, message_id, user_id, token, game_state) do
    user_game = game_state[user_id]
    target = user_game.target_number

    message = """
    😢 *Game Over* 😢

    You've used all #{@max_attempts} attempts.
    The number I was thinking of was #{target}.

    Want to play again?
    """

    # Create a keyboard with a new game button
    keyboard = %{
      "inline_keyboard" => [
        [%{"text" => "Play Again", "callback_data" => "new_game"}]
      ]
    }

    # Update the message with the new keyboard
    edit_message_with_keyboard(chat_id, message_id, message, keyboard, token)

    # Remove the user's game from the game state
    Map.delete(game_state, user_id)
  end

  # Create a keyboard with range options
  defp create_range_keyboard(min, max) do
    # Calculate range divisions
    range = max - min + 1
    division_size = div(range, 5)

    # Create range buttons
    ranges = [
      {min, min + division_size - 1},
      {min + division_size, min + 2 * division_size - 1},
      {min + 2 * division_size, min + 3 * division_size - 1},
      {min + 3 * division_size, min + 4 * division_size - 1},
      {min + 4 * division_size, max}
    ]

    # Create the keyboard
    %{
      "inline_keyboard" => [
        Enum.map(ranges, fn {range_min, range_max} ->
          %{
            "text" => "#{range_min}-#{range_max}",
            "callback_data" => "range_#{range_min}_#{range_max}"
          }
        end)
      ]
    }
  end

  # Create a keyboard with number buttons
  defp create_number_keyboard(min, max) do
    # Limit the number of buttons to avoid Telegram API limits
    range = max - min + 1

    buttons = cond do
      # If the range is small, show individual numbers
      range <= 10 ->
        Enum.map(min..max, fn num ->
          %{"text" => "#{num}", "callback_data" => "guess_#{num}"}
        end)

      # If the range is medium, show numbers in groups of 5
      range <= 50 ->
        create_grouped_buttons(min, max, 5)

      # If the range is large, show numbers in groups of 10
      true ->
        create_grouped_buttons(min, max, 10)
    end

    # Arrange buttons in rows of 5
    rows = Enum.chunk_every(buttons, 5)

    # Create the keyboard
    %{
      "inline_keyboard" => rows
    }
  end

  # Create grouped number buttons
  defp create_grouped_buttons(min, max, group_size) do
    # Create groups of numbers
    min..max
    |> Enum.chunk_every(group_size)
    |> Enum.map(fn group ->
      group_min = Enum.min(group)
      group_max = Enum.max(group)

      # For single numbers, use the number itself
      if group_min == group_max do
        %{"text" => "#{group_min}", "callback_data" => "guess_#{group_min}"}
      else
        # For groups, use the range
        mid = div(group_min + group_max, 2)
        %{"text" => "#{group_min}-#{group_max}", "callback_data" => "guess_#{mid}"}
      end
    end)
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

  # Send a message with an inline keyboard
  defp send_message_with_keyboard(chat_id, text, keyboard, token) do
    params = %{
      method: "sendMessage",
      chat_id: chat_id,
      text: text,
      parse_mode: "Markdown",
      reply_markup: keyboard,
      token: token
    }

    url = "https://api.telegram.org/bot#{token}/sendMessage"

    lens = %{
      url: url,
      method: :post,
      headers: [{"content-type", "application/json"}],
      params: Map.drop(params, [:url, :method, :token])
    }

    Client.make_request(lens, lens.params)
  end

  # Edit a message with an inline keyboard
  defp edit_message_with_keyboard(chat_id, message_id, text, keyboard, token) do
    params = %{
      method: "editMessageText",
      chat_id: chat_id,
      message_id: message_id,
      text: text,
      parse_mode: "Markdown",
      reply_markup: keyboard,
      token: token
    }

    url = "https://api.telegram.org/bot#{token}/editMessageText"

    lens = %{
      url: url,
      method: :post,
      headers: [{"content-type", "application/json"}],
      params: Map.drop(params, [:url, :method, :token])
    }

    Client.make_request(lens, lens.params)
  end

  # Edit a message without a keyboard
  defp edit_message(chat_id, message_id, text, token) do
    params = %{
      method: "editMessageText",
      chat_id: chat_id,
      message_id: message_id,
      text: text,
      token: token
    }

    url = "https://api.telegram.org/bot#{token}/editMessageText"

    lens = %{
      url: url,
      method: :post,
      headers: [{"content-type", "application/json"}],
      params: Map.drop(params, [:url, :method, :token])
    }

    Client.make_request(lens, lens.params)
  end

  # Send a message without a keyboard
  defp send_message(chat_id, text, token, opts \\ []) do
    parse_mode = Keyword.get(opts, :parse_mode)

    params = %{
      method: "sendMessage",
      chat_id: chat_id,
      text: text,
      token: token
    }

    # Add parse_mode if provided
    params = if parse_mode, do: Map.put(params, :parse_mode, parse_mode), else: params

    url = "https://api.telegram.org/bot#{token}/sendMessage"

    lens = %{
      url: url,
      method: :post,
      headers: [{"content-type", "application/json"}],
      params: Map.drop(params, [:url, :method, :token])
    }

    Client.make_request(lens, lens.params)
  end

  # Answer a callback query to stop the loading indicator
  defp answer_callback_query(query_id, token) do
    params = %{
      method: "answerCallbackQuery",
      callback_query_id: query_id,
      token: token
    }

    url = "https://api.telegram.org/bot#{token}/answerCallbackQuery"

    lens = %{
      url: url,
      method: :post,
      headers: [{"content-type", "application/json"}],
      params: Map.drop(params, [:url, :method, :token])
    }

    Client.make_request(lens, lens.params)
  end
end
