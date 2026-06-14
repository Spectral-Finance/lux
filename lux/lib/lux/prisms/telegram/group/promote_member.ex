defmodule Lux.Prisms.Telegram.Group.PromoteMember do
  @moduledoc """
  A prism for promoting a member to admin in a Telegram group.
  """

  use Lux.Prism,
    name: "Promote Telegram Member",
    description: "Promotes a user to administrator in a Telegram group",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: [:string, :integer], description: "Target chat ID"},
        user_id: %{type: :integer, description: "User ID to promote"},
        can_delete_messages: %{type: :boolean, default: false},
        can_restrict_members: %{type: :boolean, default: false},
        can_pin_messages: %{type: :boolean, default: false},
        can_manage_chat: %{type: :boolean, default: false}
      },
      required: ["chat_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        promoted: %{type: :boolean},
        chat_id: %{type: [:string, :integer]},
        user_id: %{type: :integer}
      },
      required: ["promoted", "chat_id", "user_id"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, user_id} <- validate_param(params, :user_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} promoting user #{user_id} in chat #{chat_id}")

      request_body = %{
        chat_id: chat_id,
        user_id: user_id,
        can_delete_messages: Map.get(params, :can_delete_messages, false),
        can_restrict_members: Map.get(params, :can_restrict_members, false),
        can_pin_messages: Map.get(params, :can_pin_messages, false),
        can_manage_chat: Map.get(params, :can_manage_chat, false)
      }

      case Client.request(:post, "/promoteChatMember", %{json: request_body}) do
        {:ok, %{"result" => true}} ->
          {:ok, %{promoted: true, chat_id: chat_id, user_id: user_id}}
        {:error, {status, %{"description" => desc}}} ->
          {:error, "Failed to promote member: #{desc} (HTTP #{status})"}
        {:error, error} ->
          {:error, "Failed to promote member: #{inspect(error)}"}
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