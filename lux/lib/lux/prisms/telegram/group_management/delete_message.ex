defmodule Lux.Prisms.Telegram.GroupManagement.DeleteMessage do
  @moduledoc """
  A prism for deleting a message in a chat via the Telegram Bot API.

  ## Examples

      iex> DeleteMessage.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   message_id: 101
      ...> }, %{name: "Agent"})
      {:ok, %{success: true, chat_id: 123_456_789}}
  """

  use Lux.Prism,
    name: "Delete Message",
    description: "Deletes a message in a chat",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the message to delete"
        }
      },
      required: ["chat_id", "message_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether the operation was successful"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Identifier of the target chat"
        }
      },
      required: ["success", "chat_id"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, _} <- validate_param(params, :message_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} attempting to delete message in chat #{chat_id}")

      request_body = Map.take(params, [:chat_id, :message_id])
      request_opts = %{json: request_body}
      request_opts = if params[:plug], do: Map.put(request_opts, :plug, params[:plug]), else: request_opts

      case Client.request(:post, "/deleteMessage", request_opts) do
        {:ok, %{"result" => true}} ->
          Logger.info("Successfully deleted message in chat #{chat_id}")
          {:ok, %{success: true, chat_id: chat_id}}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to delete message: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to delete message: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to delete message: #{inspect(error)}"}
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
end
