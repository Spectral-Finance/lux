defmodule Lux.Prisms.Telegram.GroupManagement.PinChatMessage do
  @moduledoc """
  A prism for adds a message to the list of pinned messages in a chat via the Telegram Bot API.

  ## Examples

      iex> PinChatMessage.handler(%{
      ...>   chat_id: 123_456_789,
...>   message_id: 42
      ...> }, %{name: "Agent"})
      {:ok, %{success: true, chat_id: 123_456_789}}
  """

  use Lux.Prism,
    name: "Pin Chat Message",
    description: "Adds a message to the list of pinned messages in a chat",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of a message to pin"
        },
        disable_notification: %{
          type: :boolean,
          description: "Pass True, if it is not necessary to send a notification to all chat members about the new pinned message"
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
      Logger.info("Agent #{agent_name} attempting to pin chat message in chat #{chat_id}")

      request_body = Map.take(params, [:chat_id, :message_id, :disable_notification])
      request_opts = %{json: request_body}
      request_opts = if params[:plug], do: Map.put(request_opts, :plug, params[:plug]), else: request_opts

      case Client.request(:post, "/pinChatMessage", request_opts) do
        {:ok, %{"result" => true}} ->
          Logger.info("Successfully completed pin chat message in chat #{chat_id}")
          {:ok, %{success: true, chat_id: chat_id}}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to pin chat message: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to pin chat message: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to pin chat message: #{inspect(error)}"}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      {:ok, value} when is_integer(value) -> {:ok, value}
      {:ok, value} when is_map(value) -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
