defmodule Lux.Prisms.Telegram.Interactive.SendGame do
  @moduledoc """
  A prism for sending games via the Telegram Bot API.

  This prism provides a simple interface to send games to Telegram chats.
  It uses the Telegram Bot API to send games that were previously set up with @BotFather.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /sendGame
  - Supports required parameters (chat_id, game_short_name) and optional parameters
  - Returns the sent message data on success
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Send a game to a chat
      iex> SendGame.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   game_short_name: "tetris"
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 42, chat_id: 123_456_789, game_short_name: "tetris"}}

      # Send a game silently (without notification)
      iex> SendGame.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   game_short_name: "tetris",
      ...>   disable_notification: true
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 42, chat_id: 123_456_789, game_short_name: "tetris"}}
  """

  use Lux.Prism,
    name: "Send Telegram Game",
    description: "Sends a game via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        message_thread_id: %{
          type: :integer,
          description: "Unique identifier for the target message thread (topic) of the forum; for forum supergroups only"
        },
        game_short_name: %{
          type: :string,
          description: "Short name of the game, serves as the unique identifier for the game. Set up your games via @BotFather."
        },
        disable_notification: %{
          type: :boolean,
          description: "Sends the message silently. Users will receive a notification with no sound"
        },
        protect_content: %{
          type: :boolean,
          description: "Protects the contents of the sent message from forwarding and saving"
        },
        reply_to_message_id: %{
          type: :integer,
          description: "If the message is a reply, ID of the original message"
        },
        allow_sending_without_reply: %{
          type: :boolean,
          description: "Pass True if the message should be sent even if the specified replied-to message is not found"
        },
        reply_markup: %{
          type: :object,
          description: "A JSON-serialized object for an inline keyboard. If empty, one 'Play game_title' button will be shown. If not empty, the first button must launch the game."
        }
      },
      required: ["chat_id", "game_short_name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{
          type: :boolean,
          description: "Whether the game was successfully sent"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the sent message"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Identifier of the target chat"
        },
        game_short_name: %{
          type: :string,
          description: "Short name of the game that was sent"
        }
      },
      required: ["sent", "message_id", "game_short_name"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to send a game to a Telegram chat.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, game_short_name} <- validate_param(params, :game_short_name) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} sending game '#{game_short_name}' to chat #{chat_id}")

      # Build the request body
      request_body = Map.take(params, [:chat_id, :message_thread_id, :game_short_name,
                                :disable_notification, :protect_content,
                                :reply_to_message_id, :allow_sending_without_reply,
                                :reply_markup])

      # Prepare request options
      request_opts = %{json: request_body}

      case Client.request(:post, "/sendGame", request_opts) do
        {:ok, %{"result" => result}} when is_map(result) ->
          Logger.info("Successfully sent game '#{game_short_name}' to chat #{chat_id}")
          {:ok, %{
            sent: true,
            message_id: result["message_id"],
            chat_id: chat_id,
            game_short_name: game_short_name
          }}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to send game: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to send game: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to send game: #{inspect(error)}"}
      end
    end
  end

  defp validate_param(params, key, _type \\ :any) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      {:ok, value} when is_integer(value) -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
