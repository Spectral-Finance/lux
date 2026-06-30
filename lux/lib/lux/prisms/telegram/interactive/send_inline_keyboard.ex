defmodule Lux.Prisms.Telegram.Interactive.SendInlineKeyboard do
  @moduledoc """
  A prism for sending messages with inline keyboard buttons via the Telegram Bot API.

  This prism provides a simple interface to send text messages with interactive buttons
  that can trigger callbacks when pressed.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /sendMessage with reply_markup field
  - Supports required parameters (chat_id, text, inline_keyboard) and optional parameters
  - Returns the sent message data on success
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Send a message with an inline keyboard
      iex> SendInlineKeyboard.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   text: "Please choose an option:",
      ...>   inline_keyboard: [
      ...>     [
      ...>       %{text: "Option 1", callback_data: "option_1"},
      ...>       %{text: "Option 2", callback_data: "option_2"}
      ...>     ],
      ...>     [
      ...>       %{text: "Visit Website", url: "https://example.com"}
      ...>     ]
      ...>   ]
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 42, chat_id: 123_456_789, text: "Please choose an option:"}}

      # Send a message with an inline keyboard and markdown formatting
      iex> SendInlineKeyboard.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   text: "*Bold* and _italic_ text",
      ...>   parse_mode: "Markdown",
      ...>   inline_keyboard: [
      ...>     [
      ...>       %{text: "Yes", callback_data: "yes"},
      ...>       %{text: "No", callback_data: "no"}
      ...>     ]
      ...>   ]
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 42, chat_id: 123_456_789, text: "*Bold* and _italic_ text"}}
  """

  use Lux.Prism,
    name: "Send Telegram Inline Keyboard",
    description: "Sends a message with inline keyboard buttons via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        text: %{
          type: :string,
          description: "Text of the message to be sent"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the message text",
          enum: ["Markdown", "MarkdownV2", "HTML"]
        },
        disable_web_page_preview: %{
          type: :boolean,
          description: "Disables link previews for links in this message"
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
        inline_keyboard: %{
          type: :array,
          description: "A JSON-serialized array of button rows, where each row is an array of InlineKeyboardButton objects",
          items: %{
            type: :array,
            description: "A row of buttons",
            items: %{
              type: :object,
              description: "An inline keyboard button",
              properties: %{
                text: %{
                  type: :string,
                  description: "Label text on the button"
                },
                url: %{
                  type: :string,
                  description: "HTTP or tg:// URL to be opened when the button is pressed"
                },
                callback_data: %{
                  type: :string,
                  description: "Data to be sent in a callback query to the bot when the button is pressed, 1-64 bytes"
                },
                web_app: %{
                  type: :object,
                  description: "Description of the Web App that will be launched when the user presses the button",
                  properties: %{
                    url: %{
                      type: :string,
                      description: "An HTTPS URL of a Web App to be opened with additional data"
                    }
                  }
                },
                login_url: %{
                  type: :object,
                  description: "An HTTPS URL used to automatically authorize the user",
                  properties: %{
                    url: %{
                      type: :string,
                      description: "An HTTPS URL to be opened with user authorization data added to the query string"
                    },
                    forward_text: %{
                      type: :string,
                      description: "New text of the button in forwarded messages"
                    },
                    bot_username: %{
                      type: :string,
                      description: "Username of a bot, which will be used for user authorization"
                    },
                    request_write_access: %{
                      type: :boolean,
                      description: "Pass True to request the permission for your bot to send messages to the user"
                    }
                  }
                },
                switch_inline_query: %{
                  type: :string,
                  description: "If set, pressing the button will prompt the user to select one of their chats"
                },
                switch_inline_query_current_chat: %{
                  type: :string,
                  description: "If set, pressing the button will insert the bot's username and the specified inline query in the current chat's input field"
                },
                pay: %{
                  type: :boolean,
                  description: "Specify True, to send a Pay button"
                }
              },
              required: ["text"]
            }
          }
        }
      },
      required: ["chat_id", "text", "inline_keyboard"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{
          type: :boolean,
          description: "Whether the message with inline keyboard was successfully sent"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the sent message"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Identifier of the target chat"
        },
        text: %{
          type: :string,
          description: "Text of the sent message"
        }
      },
      required: ["sent", "message_id", "text"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to send a message with an inline keyboard to a Telegram chat.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, text} <- validate_param(params, :text),
         {:ok, inline_keyboard} <- validate_inline_keyboard(params) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} sending message with inline keyboard to chat #{chat_id}")

      # Build the reply_markup for the inline keyboard
      reply_markup = %{
        inline_keyboard: inline_keyboard
      }

      # Build the request body
      request_body = Map.take(params, [:chat_id, :text, :parse_mode,
                              :disable_web_page_preview, :disable_notification,
                              :protect_content, :reply_to_message_id,
                              :allow_sending_without_reply])
                     |> Map.put(:reply_markup, reply_markup)

      # Prepare request options
      request_opts = %{json: request_body}

      case Client.request(:post, "/sendMessage", request_opts) do
        {:ok, %{"result" => result}} when is_map(result) ->
          Logger.info("Successfully sent message with inline keyboard to chat #{chat_id}")

          {:ok, %{
            sent: true,
            message_id: result["message_id"],
            chat_id: chat_id,
            text: text
          }}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to send message with inline keyboard: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to send message with inline keyboard: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to send message with inline keyboard: #{inspect(error)}"}
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

  defp validate_inline_keyboard(params) do
    case Map.fetch(params, :inline_keyboard) do
      {:ok, inline_keyboard} when is_list(inline_keyboard) ->
        validate_inline_keyboard_rows(inline_keyboard)
      _ ->
        {:error, "Missing or invalid inline_keyboard"}
    end
  end

  defp validate_inline_keyboard_rows(inline_keyboard) do
    if Enum.all?(inline_keyboard, &is_list/1) do
      {:ok, inline_keyboard}
    else
      {:error, "Invalid inline_keyboard format: must be a list of button rows"}
    end
  end
end
