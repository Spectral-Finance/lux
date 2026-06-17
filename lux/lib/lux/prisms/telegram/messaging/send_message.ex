defmodule Lux.Prisms.Telegram.Messaging.SendMessage do
  @moduledoc """
  A prism for sending messages to Telegram chats.

  ## Examples

      iex> SendMessage.handler(%{
      ...>   chat_id: "123456",
      ...>   text: "Hello, Telegram!"
      ...> }, %{name: "Agent"})
      {:ok, %{
        sent: true,
        message_id: 42,
        text: "Hello, Telegram!",
        chat_id: "123456"
      }}

  """

  use Lux.Prism,
    name: "Send Telegram Message",
    description: "Sends a message to a Telegram chat",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: :string,
          description: "The ID of the chat to send the message to"
        },
        text: %{
          type: :string,
          description: "The message text to send",
          minLength: 1,
          maxLength: 4096
        },
        parse_mode: %{
          type: :string,
          description: "The parse mode for the message (MarkdownV2, HTML)",
          enum: ["MarkdownV2", "HTML"]
        },
        reply_to_message_id: %{
          type: :integer,
          description: "The ID of the message to reply to"
        },
        reply_markup: %{
          type: :object,
          description: "Additional interface options (inline keyboard, etc.)"
        }
      },
      required: ["chat_id", "text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{
          type: :boolean,
          description: "Whether the message was successfully sent"
        },
        message_id: %{
          type: :integer,
          description: "The ID of the sent message"
        },
        text: %{
          type: :string,
          description: "The text of the sent message"
        },
        chat_id: %{
          type: :string,
          description: "The ID of the chat where the message was sent"
        }
      },
      required: ["sent"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to send a message to a Telegram chat.
  """
  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, text} <- validate_param(params, :text) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} sending message to chat #{chat_id}: #{text}")

      json = %{chat_id: chat_id, text: text}
      json = maybe_add_optional(json, params, :parse_mode)
      json = maybe_add_optional(json, params, :reply_to_message_id)
      json = maybe_add_optional(json, params, :reply_markup)

      case Client.request(:post, "/sendMessage", %{json: json}) do
        {:ok, %{"result" => %{"message_id" => message_id}}} ->
          Logger.info("Successfully sent message #{message_id} to chat #{chat_id}")
          {:ok, %{sent: true, message_id: message_id, text: text, chat_id: chat_id}}

        {:error, {status, description}} ->
          error = {status, description}
          Logger.error("Failed to send message to chat #{chat_id}: #{inspect(error)}")
          {:error, error}

        {:error, error} ->
          Logger.error("Failed to send message to chat #{chat_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      {:ok, value} when is_integer(value) -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp maybe_add_optional(json, params, key) do
    case Map.fetch(params, key) do
      {:ok, value} -> Map.put(json, key, value)
      :error -> json
    end
  end
end
