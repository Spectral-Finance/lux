defmodule Lux.Prisms.Telegram.Group.BanMember do
  @moduledoc """
  A prism for banning a member from a Telegram group.

  ## Examples

      iex> BanMember.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   user_id: 987_654_321
      ...> }, %{name: "Agent"})
      {:ok, %{banned: true, chat_id: 123_456_789, user_id: 987_654_321}}
  """

  use Lux.Prism,
    name: "Ban Telegram Member",
    description: "Bans a user from a Telegram group or channel",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: [:string, :integer], description: "Target chat ID"},
        user_id: %{type: :integer, description: "User ID to ban"},
        until_date: %{type: :integer, description: "Unix time when ban will be lifted. 0 = permanent"}
      },
      required: ["chat_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        banned: %{type: :boolean},
        chat_id: %{type: [:string, :integer]},
        user_id: %{type: :integer}
      },
      required: ["banned", "chat_id", "user_id"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, user_id} <- validate_param(params, :user_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} banning user #{user_id} from chat #{chat_id}")

      request_body = %{
        chat_id: chat_id,
        user_id: user_id,
        until_date: Map.get(params, :until_date, 0)
      }

      case Client.request(:post, "/banChatMember", %{json: request_body}) do
        {:ok, %{"result" => true}} ->
          {:ok, %{banned: true, chat_id: chat_id, user_id: user_id}}
        {:error, {status, %{"description" => desc}}} ->
          {:error, "Failed to ban member: #{desc} (HTTP #{status})"}
        {:error, error} ->
          {:error, "Failed to ban member: #{inspect(error)}"}
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