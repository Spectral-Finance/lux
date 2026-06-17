defmodule Lux.Prisms.Telegram.Media.SendDocument do
  @moduledoc """
  A prism for sending documents to Telegram chats.
  """

  use Lux.Prism,
    name: "Send Telegram Document",
    description: "Sends a document to a Telegram chat",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: :string, description: "The ID of the chat"},
        document: %{type: :string, description: "File ID or URL of the document"},
        caption: %{type: :string, description: "Document caption (0-1024 characters)", maxLength: 1024},
        parse_mode: %{type: :string, description: "Parse mode for caption", enum: ["MarkdownV2", "HTML"]},
        reply_to_message_id: %{type: :integer, description: "ID of the message to reply to"}
      },
      required: ["chat_id", "document"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{type: :boolean, description: "Whether the document was sent"},
        message_id: %{type: :integer, description: "The ID of the sent message"},
        chat_id: %{type: :string, description: "The ID of the chat"}
      },
      required: ["sent"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, document} <- validate_param(params, :document) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} sending document to chat #{chat_id}")

      json = %{chat_id: chat_id, document: document}
      json = maybe_add_optional(json, params, :caption)
      json = maybe_add_optional(json, params, :parse_mode)
      json = maybe_add_optional(json, params, :reply_to_message_id)

      case Client.request(:post, "/sendDocument", %{json: json}) do
        {:ok, %{"result" => %{"message_id" => message_id}}} ->
          Logger.info("Successfully sent document #{message_id} to chat #{chat_id}")
          {:ok, %{sent: true, message_id: message_id, chat_id: chat_id}}

        {:error, {status, description}} ->
          Logger.error("Failed to send document: {#{status}, #{description}}")
          {:error, {status, description}}

        {:error, error} ->
          Logger.error("Failed to send document: #{inspect(error)}")
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
