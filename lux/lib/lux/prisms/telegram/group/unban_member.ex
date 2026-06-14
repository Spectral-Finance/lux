defmodule Lux.Prisms.Telegram.Group.UnbanMember do
  @moduledoc """
  A prism for unbanning a member from a Telegram group.
  """

  use Lux.Prism,
    name: "Unban Telegram Member",
    description: "Unbans a user from a Telegram group or channel",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: [:string, :integer], description: "Target chat ID"},
        user_id: %{type: :integer, description: "User ID to unban"}
      },
      required: ["chat_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        unbanned: %{type: :boolean},
        chat_id: %{type: [:string, :integer]},
        user_id: %{type: :integer}
      },
      required: ["unbanned", "chat_id", "user_id"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, user_id} <- validate_param(params, :user_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} unbanning user #{user_id} from chat #{chat_id}")

      case Client.request(:post, "/unbanChatMember", %{json: %{chat_id: chat_id, user_id: user_id}}) do
        {:ok, %{"result" => true}} ->
          {:ok, %{unbanned: true, chat_id: chat_id, user_id: user_id}}
        {:error, {status, %{"description" => desc}}} ->
          {:error, "Failed to unban member: #{desc} (HTTP #{status})"}
        {:error, error} ->
          {:error, "Failed to unban member: #{inspect(error)}"}
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