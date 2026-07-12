defmodule Lux.Prisms.Telegram.GroupManagement.SetChatPermissions do
  @moduledoc """
  A prism for sets default chat permissions for all members via the Telegram Bot API.

  ## Examples

      iex> SetChatPermissions.handler(%{
      ...>   chat_id: 123_456_789,
...>   permissions: %{can_send_messages: true}
      ...> }, %{name: "Agent"})
      {:ok, %{success: true, chat_id: 123_456_789}}
  """

  use Lux.Prism,
    name: "Set Chat Permissions",
    description: "Sets default chat permissions for all members",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat"
        },
        permissions: %{
          type: :object,
          description: "New default chat permissions"
        }
      },
      required: ["chat_id", "permissions"]
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
         {:ok, _} <- validate_param(params, :permissions) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} attempting to set chat permissions in chat #{chat_id}")

      request_body = Map.take(params, [:chat_id, :permissions])
      request_opts = %{json: request_body}
      request_opts = if params[:plug], do: Map.put(request_opts, :plug, params[:plug]), else: request_opts

      case Client.request(:post, "/setChatPermissions", request_opts) do
        {:ok, %{"result" => true}} ->
          Logger.info("Successfully completed set chat permissions in chat #{chat_id}")
          {:ok, %{success: true, chat_id: chat_id}}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to set chat permissions: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to set chat permissions: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to set chat permissions: #{inspect(error)}"}
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
