defmodule Lux.Prisms.Telegram.GroupManagement.RestrictChatMember do
  @moduledoc """
  A prism for restricts a member in a supergroup via the Telegram Bot API.

  ## Examples

      iex> RestrictChatMember.handler(%{
      ...>   chat_id: 123_456_789,
...>   user_id: 987_654,
...>   permissions: %{can_send_messages: true}
      ...> }, %{name: "Agent"})
      {:ok, %{success: true, chat_id: 123_456_789}}
  """

  use Lux.Prism,
    name: "Restrict Chat Member",
    description: "Restricts a member in a supergroup",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat"
        },
        user_id: %{
          type: :integer,
          description: "Unique identifier of the target user"
        },
        permissions: %{
          type: :object,
          description: "An object for new user permissions"
        },
        until_date: %{
          type: :integer,
          description: "Date when restrictions will be lifted"
        }
      },
      required: ["chat_id", "user_id", "permissions"]
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
         {:ok, _} <- validate_param(params, :user_id),
         {:ok, _} <- validate_param(params, :permissions) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} attempting to restrict member in chat #{chat_id}")

      request_body = Map.take(params, [:chat_id, :user_id, :permissions, :until_date])
      request_opts = %{json: request_body}
      request_opts = if params[:plug], do: Map.put(request_opts, :plug, params[:plug]), else: request_opts

      case Client.request(:post, "/restrictChatMember", request_opts) do
        {:ok, %{"result" => true}} ->
          Logger.info("Successfully completed restrict member in chat #{chat_id}")
          {:ok, %{success: true, chat_id: chat_id}}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to restrict member: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to restrict member: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to restrict member: #{inspect(error)}"}
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
