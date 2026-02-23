defmodule Lux.Prisms.Telegram.Messages.SendReply do
  @moduledoc """
  A prism for sending threaded replies to Telegram messages.

  Sends a reply to a specific message, creating a message thread.
  Supports forum topic threads in supergroups and optional quote text.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /sendMessage with reply_parameters
  - Supports reply_to_message_id for standard replies
  - Supports message_thread_id for forum supergroup threads
  - Optionally allows message to send even if original is deleted
  - Returns the sent message ID and thread context

  ## Examples

      iex> SendReply.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   message_id: 42,
      ...>   text: "Great point!"
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 456, chat_id: 123_456_789, reply_to_message_id: 42}}

      iex> SendReply.handler(%{
      ...>   chat_id: -1001234567890,
      ...>   message_id: 42,
      ...>   message_thread_id: 10,
      ...>   text: "Forum thread reply"
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 789, chat_id: -1001234567890, reply_to_message_id: 42}}
  """

  use Lux.Prism,
    name: "Send Telegram Reply",
    description: "Sends a threaded reply to a specific Telegram message, supporting forum topics and standard replies",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat"
        },
        message_id: %{
          type: :integer,
          description: "ID of the message to reply to"
        },
        text: %{
          type: :string,
          description: "Reply text"
        },
        message_thread_id: %{
          type: :integer,
          description: "Unique identifier for the target message thread (forum topic). For forum supergroups only."
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the reply text",
          enum: ["Markdown", "MarkdownV2", "HTML"]
        },
        allow_sending_without_reply: %{
          type: :boolean,
          description: "Pass True if the reply should be sent even if the original message was deleted"
        },
        disable_notification: %{
          type: :boolean,
          description: "Send the reply silently"
        }
      },
      required: ["chat_id", "message_id", "text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{type: :boolean},
        message_id: %{type: :integer, description: "ID of the sent reply"},
        chat_id: %{description: "The chat where the reply was sent"},
        reply_to_message_id: %{type: :integer, description: "The original message ID that was replied to"}
      }
    }

  alias Lux.Integrations.Telegram.Client

  @impl true
  def handler(params, _agent) do
    chat_id = params[:chat_id] || params["chat_id"]
    message_id = params[:message_id] || params["message_id"]
    text = params[:text] || params["text"]
    message_thread_id = params[:message_thread_id] || params["message_thread_id"]
    parse_mode = params[:parse_mode] || params["parse_mode"]
    allow_without_reply = params[:allow_sending_without_reply] || params["allow_sending_without_reply"] || false
    disable_notification = params[:disable_notification] || params["disable_notification"] || false

    body =
      %{
        chat_id: chat_id,
        text: text,
        reply_to_message_id: message_id,
        allow_sending_without_reply: allow_without_reply,
        disable_notification: disable_notification
      }
      |> maybe_put(:message_thread_id, message_thread_id)
      |> maybe_put(:parse_mode, parse_mode)

    case Client.request(:post, "/sendMessage", %{json: body, plug: params[:plug]}) do
      {:ok, %{"ok" => true, "result" => result}} ->
        {:ok, %{
          sent: true,
          message_id: result["message_id"],
          chat_id: chat_id,
          reply_to_message_id: message_id
        }}

      {:error, %{"ok" => false, "description" => desc}} ->
        {:error, desc}

      {:error, {_status, desc}} when is_binary(desc) ->
        {:error, desc}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
