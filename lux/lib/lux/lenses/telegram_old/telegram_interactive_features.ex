defmodule Lux.Lenses.TelegramInteractiveFeatures do
  @moduledoc """
  Interactive features for the Telegram Bot API.

  This module provides specialized functionality for interactive Telegram Bot features:

  ## Features

  Polls & Quizzes: Full support for creating and managing polls and quizzes
  Games: Game score tracking and leaderboard management
  Live Location: Real-time location sharing and updates
  Stickers: Complete sticker set management and handling
  Inline Queries: Rich inline query processing with multiple result types
  Interactive Elements: Inline keyboards, custom keyboards, and callback handling

  ## Example

  ```elixir
  alias Lux.Lenses.TelegramInteractiveFeatures

  # Send a quiz
  TelegramInteractiveFeatures.send_quiz(
    chat_id,
    "What is the capital of France?",
    ["Paris", "London", "Berlin", "Madrid"],
    0
  )

  # Send a game
  TelegramInteractiveFeatures.send_game(
    chat_id,
    "my_game"
  )

  # Send a live location
  TelegramInteractiveFeatures.send_live_location(
    chat_id,
    48.8566,
    2.3522,
    60
  )
  ```
  """

  alias Lux.Lenses.TelegramBotLens

  @doc """
  Creates a quiz poll.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `question`: Poll question, 1-300 characters
  - `options`: List of answer options, 2-10 strings 1-100 characters each
  - `correct_option_id`: 0-based identifier of the correct answer option
  - `opts`: Additional options for the quiz

  ## Returns

  Returns the sent message on success.
  """
  def send_quiz(chat_id, question, options, correct_option_id, opts \\ %{}) do
    params = Map.merge(
      %{
        method: "sendPoll",
        chat_id: chat_id,
        question: question,
        options: options,
        type: "quiz",
        correct_option_id: correct_option_id,
        token: Lux.Config.telegram_bot_token()
      },
      opts
    )

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Sends a poll to a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat or username of the target channel
  - `question`: Poll question, 1-300 characters
  - `options`: List of answer options, 2-10 strings 1-100 characters each
  - `opts`: Additional options for the poll (is_anonymous, type, etc.)

  ## Returns

  Returns the sent message on success.
  """
  def send_poll(chat_id, question, options, opts \\ %{}) do
    TelegramBotLens.telegram_request(
      Map.merge(
        %{
          method: "sendPoll",
          chat_id: chat_id,
          question: question,
          options: options,
          token: Lux.Config.telegram_bot_token()
        },
        opts
      )
    )
  end

  @doc """
  Stops a poll.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `message_id`: Identifier of the message with the poll
  - `opts`: Additional options

  ## Returns

  Returns the stopped poll on success.
  """
  def stop_poll(chat_id, message_id, opts \\ %{}) do
    params = Map.merge(
      %{
        method: "stopPoll",
        chat_id: chat_id,
        message_id: message_id,
        token: Lux.Config.telegram_bot_token()
      },
      opts
    )

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Sends a game.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `game_short_name`: Short name of the game (registered with @BotFather)
  - `opts`: Additional options (disable_notification, protect_content, reply_parameters)

  ## Returns

  Returns the sent message on success.
  """
  def send_game(chat_id, game_short_name, opts \\ %{}) do
    params = Map.merge(
      %{
        method: "sendGame",
        chat_id: chat_id,
        game_short_name: game_short_name,
        token: Lux.Config.telegram_bot_token()
      },
      opts
    )

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Sets the game score for a user.

  ## Parameters

  - `user_id`: User identifier
  - `score`: New score value (must be non-negative)
  - `force`: Pass True to update the score even if it's lower than the user's current score
  - `chat_id`: Required if inline_message_id is not specified
  - `message_id`: Required if inline_message_id is not specified
  - `inline_message_id`: Required if chat_id and message_id are not specified
  - `disable_edit_message`: Don't edit the game message to include the current scoreboard

  ## Returns

  Returns the edited message on success.
  """
  def set_game_score(user_id, score, opts \\ %{}) do
    # Validate required parameters
    unless (opts[:chat_id] && opts[:message_id]) || opts[:inline_message_id] do
      raise ArgumentError, "Either chat_id and message_id or inline_message_id must be provided"
    end

    params = Map.merge(
      %{
        method: "setGameScore",
        user_id: user_id,
        score: score,
        token: Lux.Config.telegram_bot_token()
      },
      opts
    )

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Gets the high scores for a game.

  ## Parameters

  - `user_id`: Target user id
  - `chat_id`: Required if inline_message_id is not specified
  - `message_id`: Required if inline_message_id is not specified
  - `inline_message_id`: Required if chat_id and message_id are not specified

  ## Returns

  Returns Array of GameHighScore on success.
  """
  def get_game_high_scores(user_id, opts \\ %{}) do
    # Validate required parameters
    unless (opts[:chat_id] && opts[:message_id]) || opts[:inline_message_id] do
      raise ArgumentError, "Either chat_id and message_id or inline_message_id must be provided"
    end

    params = Map.merge(
      %{
        method: "getGameHighScores",
        user_id: user_id,
        token: Lux.Config.telegram_bot_token()
      },
      opts
    )

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Sends a live location.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `latitude`: Latitude of the location
  - `longitude`: Longitude of the location
  - `live_period`: Period in seconds for which the location will be updated
  - `opts`: Additional options

  ## Returns

  Returns the sent message on success.
  """
  def send_live_location(chat_id, latitude, longitude, live_period, opts \\ %{}) do
    params = Map.merge(
      %{
        method: "sendLocation",
        chat_id: chat_id,
        latitude: latitude,
        longitude: longitude,
        live_period: live_period,
        token: Lux.Config.telegram_bot_token()
      },
      opts
    )

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Edits a live location.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `message_id`: Identifier of the message with live location to edit
  - `latitude`: New latitude
  - `longitude`: New longitude
  - `opts`: Additional options

  ## Returns

  Returns the edited message on success.
  """
  def edit_live_location(chat_id, message_id, latitude, longitude, opts \\ %{}) do
    params = Map.merge(
      %{
        method: "editMessageLiveLocation",
        chat_id: chat_id,
        message_id: message_id,
        latitude: latitude,
        longitude: longitude,
        token: Lux.Config.telegram_bot_token()
      },
      opts
    )

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Stops updating a live location.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `message_id`: Identifier of the message with live location
  - `opts`: Additional options

  ## Returns

  Returns the edited message on success.
  """
  def stop_live_location(chat_id, message_id, opts \\ %{}) do
    params = Map.merge(
      %{
        method: "stopMessageLiveLocation",
        chat_id: chat_id,
        message_id: message_id,
        token: Lux.Config.telegram_bot_token()
      },
      opts
    )

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Gets a sticker set.

  ## Parameters

  - `name`: Name of the sticker set

  ## Returns

  Returns the StickerSet object on success.
  """
  def get_sticker_set(name) do
    params = %{
      method: "getStickerSet",
      name: name,
      token: Lux.Config.telegram_bot_token()
    }

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Sends a sticker to a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat or username of the target channel
  - `sticker`: Sticker to send (file_id, URL, or file path)
  - `opts`: Additional options for the message (disable_notification, etc.)

  ## Returns

  Returns the sent message on success.
  """
  def send_sticker(chat_id, sticker, opts \\ %{}) do
    TelegramBotLens.telegram_request(
      Map.merge(
        %{
          method: "sendSticker",
          chat_id: chat_id,
          sticker: sticker,
          token: Lux.Config.telegram_bot_token()
        },
        opts
      )
    )
  end

  @doc """
  Creates an InlineQueryResultArticle.

  ## Parameters

  - `id`: Unique identifier for this result
  - `title`: Title of the result
  - `input_message_content`: Content to be sent
  - `opts`: Additional options (description, thumbnail_url, etc.)

  ## Returns

  Returns an InlineQueryResultArticle object.
  """
  def create_article_result(id, title, input_message_content, opts \\ %{}) do
    Map.merge(
      %{
        type: "article",
        id: id,
        title: title,
        input_message_content: input_message_content
      },
      opts
    )
  end

  @doc """
  Creates a text message content for inline results.

  ## Parameters

  - `text`: Text of the message
  - `opts`: Additional options (parse_mode, disable_web_page_preview)

  ## Returns

  Returns an InputTextMessageContent object.
  """
  def create_text_content(text, opts \\ %{}) do
    Map.merge(
      %{
        message_text: text
      },
      opts
    )
  end

  @doc """
  Creates an InlineQueryResultPhoto.

  ## Parameters

  - `id`: Unique identifier for this result
  - `photo_url`: URL of the photo
  - `thumbnail_url`: URL of the thumbnail
  - `opts`: Additional options (title, description, caption)

  ## Returns

  Returns an InlineQueryResultPhoto object.
  """
  def create_photo_result(id, photo_url, thumbnail_url, opts \\ %{}) do
    Map.merge(
      %{
        type: "photo",
        id: id,
        photo_url: photo_url,
        thumbnail_url: thumbnail_url
      },
      opts
    )
  end

  @doc """
  Answers an inline query with results.

  ## Parameters

  - `inline_query_id`: Unique identifier for the answered query
  - `results`: Array of InlineQueryResult objects
  - `opts`: Additional options (cache_time, is_personal, next_offset, etc.)

  ## Returns

  Returns true on success.
  """
  def answer_inline_query(inline_query_id, results, opts \\ %{}) do
    params = Map.merge(
      %{
        method: "answerInlineQuery",
        inline_query_id: inline_query_id,
        results: results,
        token: Lux.Config.telegram_bot_token()
      },
      opts
    )

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Sets the bot's inline query handler.

  ## Parameters

  - `handler`: Function that takes an inline query and returns results
  - `opts`: Additional options (cache_time, is_personal, etc.)

  ## Example

  ```elixir
  TelegramInteractiveFeatures.set_inline_handler(fn query ->
    text_content = TelegramInteractiveFeatures.create_text_content("You searched for: \#{query["query"]}")
    result = TelegramInteractiveFeatures.create_article_result(
      "1",
      "Search Result",
      text_content,
      %{description: "Click to send the search result"}
    )
    [result]
  end)
  ```
  """
  def set_inline_handler(handler, opts \\ %{}) do
    # Store the handler in the process dictionary
    Process.put(:telegram_inline_handler, {handler, opts})
  end

  @doc """
  Processes an inline query using the set handler.

  ## Parameters

  - `inline_query`: The inline query object from Telegram

  ## Returns

  Returns the result of answering the inline query.
  """
  def process_inline_query(inline_query) do
    case Process.get(:telegram_inline_handler) do
      {handler, opts} ->
        # Call the handler to get results
        results = handler.(inline_query)
        # Answer the inline query
        answer_inline_query(
          inline_query["id"],
          results,
          opts
        )

      nil ->
        {:error, "No inline query handler set"}
    end
  end
end
