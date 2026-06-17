defmodule Lux.Prisms.Telegram.Messaging.EditMessage do
  @moduledoc """
  A prism for editing messages in Telegram chats.
  """

  use Lux.Prism,
    name: "Edit Telegram Message",
    description: "Edits a message in a Telegram chat",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: :string, description: "The ID of the chat"},
        message_id: %{type: :integer, description: "The ID of the message to edit"},
        text: %{type: :string, description: "The new message text", minLength: 1, maxLength: 4096},
        parse_mode: %{type: :string, description: "The parse mode (MarkdownV2, HTML)", enum: ["MarkdownV2", "HTML"]},
        reply_markup: %{type: :object, description: "Inline keyboard markup"}
      },
      required: ["chat_id", "message_id", "text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        edited: %{type: :boolean, description: "Whether the message was edited"},
        message_id: %{type: :integer, description: "The ID of the edited message"},
        chat_id: %{type: :string, description: "The ID of the chat"}
      },
      required: ["edited"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, message_id} <- validate_param(params, :message_id),
         {:ok, text} <- validate_param(params, :text) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} editing message #{message_id} in chat #{chat_id}")

      json = %{chat_id: chat_id, message_id: message_id, text: text}
      json = maybe_add_optional(json, params, :parse_mode)
      json = maybe_add_optional(json, params, :reply_markup)

      case Client.request(:post, "/editMessageText", %{json: json}) do
        {:ok, _result} ->
          Logger.info("Successfully edited message #{message_id} in chat #{chat_id}")
          {:ok, %{edited: true, message_id: message_id, chat_id: chat_id}}

        {:error, {status, description}} ->
          Logger.error("Failed to edit message: {#{status}, #{description}}")
          {:error, {status, description}}

        {:error, error} ->
          Logger.error("Failed to edit message: #{inspect(error)}")
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
