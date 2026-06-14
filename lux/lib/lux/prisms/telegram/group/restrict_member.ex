defmodule Lux.Prisms.Telegram.Group.RestrictMember do
  @moduledoc """
  A prism for restricting a member in a Telegram group.
  """

  use Lux.Prism,
    name: "Restrict Telegram Member",
    description: "Restricts a user in a Telegram group",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: [:string, :integer], description: "Target chat ID"},
        user_id: %{type: :integer, description: "User ID to restrict"},
        can_send_messages: %{type: :boolean, description: "Allow sending messages", default: false},
        can_send_media: %{type: :boolean, description: "Allow sending media", default: false},
        until_date: %{type: :integer, description: "Unix time when restriction ends"}
      },
      required: ["chat_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        restricted: %{type: :boolean},
        chat_id: %{type: [:string, :integer]},
        user_id: %{type: :integer}
      },
      required: ["restricted", "chat_id", "user_id"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, user_id} <- validate_param(params, :user_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} restricting user #{user_id} in chat #{chat_id}")

      permissions = %{
        can_send_messages: Map.get(params, :can_send_messages, false),
        can_send_media_messages: Map.get(params, :can_send_media, false),
        can_send_polls: false,
        can_send_other_messages: false,
        can_add_web_page_previews: false
      }

      request_body = %{
        chat_id: chat_id,
        user_id: user_id,
        permissions: permissions,
        until_date: Map.get(params, :until_date, 0)
      }

      case Client.request(:post, "/restrictChatMember", %{json: request_body}) do
        {:ok, %{"result" => true}} ->
          {:ok, %{restricted: true, chat_id: chat_id, user_id: user_id}}
        {:error, {status, %{"description" => desc}}} ->
          {:error, "Failed to restrict member: #{desc} (HTTP #{status})"}
        {:error, error} ->
          {:error, "Failed to restrict member: #{inspect(error)}"}
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