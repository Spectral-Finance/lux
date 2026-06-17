defmodule Lux.Prisms.Telegram.Interactive.SendInlineKeyboard do
  @moduledoc """
  A prism for sending messages with inline keyboards to Telegram chats.
  """

  use Lux.Prism,
    name: "Send Telegram Inline Keyboard",
    description: "Sends a message with inline keyboard buttons to a Telegram chat",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: :string, description: "The ID of the chat"},
        text: %{type: :string, description: "The message text", minLength: 1, maxLength: 4096},
        parse_mode: %{type: :string, description: "Parse mode", enum: ["MarkdownV2", "HTML"]},
        inline_keyboard: %{
          type: :array,
          description: "Array of button rows, each row is an array of buttons",
          items: %{
            type: :array,
            items: %{
              type: :object,
              properties: %{
                text: %{type: :string, description: "Button text"},
                callback_data: %{type: :string, description: "Data to be sent in a callback query"},
                url: %{type: :string, description: "URL to open when button is pressed"}
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
        sent: %{type: :boolean, description: "Whether the message was sent"},
        message_id: %{type: :integer, description: "The ID of the sent message"},
        chat_id: %{type: :string, description: "The ID of the chat"}
      },
      required: ["sent"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, text} <- validate_param(params, :text),
         {:ok, inline_keyboard} <- validate_keyboard(params) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} sending inline keyboard to chat #{chat_id}")

      reply_markup = %{inline_keyboard: inline_keyboard}
      json = %{chat_id: chat_id, text: text, reply_markup: reply_markup}
      json = maybe_add_optional(json, params, :parse_mode)

      case Client.request(:post, "/sendMessage", %{json: json}) do
        {:ok, %{"result" => %{"message_id" => message_id}}} ->
          Logger.info("Successfully sent inline keyboard #{message_id} to chat #{chat_id}")
          {:ok, %{sent: true, message_id: message_id, chat_id: chat_id}}

        {:error, {status, description}} ->
          Logger.error("Failed to send inline keyboard: {#{status}, #{description}}")
          {:error, {status, description}}

        {:error, error} ->
          Logger.error("Failed to send inline keyboard: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      {:ok, value} when is_list(value) -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_keyboard(params) do
    case Map.fetch(params, :inline_keyboard) do
      {:ok, keyboard} when is_list(keyboard) and length(keyboard) > 0 -> {:ok, keyboard}
      _ -> {:error, "Missing or invalid inline_keyboard"}
    end
  end

  defp maybe_add_optional(json, params, key) do
    case Map.fetch(params, key) do
      {:ok, value} -> Map.put(json, key, value)
      :error -> json
    end
  end
end
