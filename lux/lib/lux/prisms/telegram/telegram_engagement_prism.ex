defmodule Lux.Prisms.Telegram.TelegramEngagementPrism do
  @moduledoc """
  A prism for tracking Telegram bot user engagement.

  ## Example

      iex> Lux.Prisms.Telegram.TelegramEngagementPrism.handler(%{
      ...>   chat_id: 123456789,
      ...>   action: "get_engagement_score"
      ...> }, %{})
  """

  use Lux.Prism,
    name: "Telegram User Engagement",
    description: "Tracks user engagement metrics for Telegram bots",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: :integer, description: "Telegram chat ID"},
        action: %{
          type: :string,
          enum: ["get_members", "get_admins", "get_engagement_score"],
          default: "get_engagement_score"
        },
        token: %{type: :string, description: "Bot token (optional)"}
      },
      required: ["chat_id", "action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        member_count: %{type: :integer},
        admin_count: %{type: :integer},
        engagement_score: %{type: :number},
        status: %{type: :string}
      },
      required: ["status"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(input, _ctx) do
    Logger.info("Telegram engagement: #{input.action} for chat #{input.chat_id}")
    opts = build_opts(input)

    case input.action do
      "get_members" -> get_member_count(input.chat_id, opts)
      "get_admins" -> get_admins(input.chat_id, opts)
      "get_engagement_score" -> get_engagement_score(input.chat_id, opts)
      _ -> {:error, "Unknown action: #{input.action}"}
    end
  end

  defp get_member_count(chat_id, opts) do
    case Client.request(:post, "/getChatMemberCount", Map.put(opts, :json, %{chat_id: chat_id})) do
      {:ok, %{"result" => count}} -> {:ok, %{member_count: count, status: "success"}}
      {:error, reason} -> {:error, "Failed: #{inspect(reason)}"}
    end
  end

  defp get_admins(chat_id, opts) do
    case Client.request(:post, "/getChatAdministrators", Map.put(opts, :json, %{chat_id: chat_id})) do
      {:ok, %{"result" => admins}} ->
        {:ok, %{admin_count: length(admins), admins: Enum.map(admins, & &1["user"]), status: "success"}}
      {:error, reason} -> {:error, "Failed: #{inspect(reason)}"}
    end
  end

  defp get_engagement_score(chat_id, opts) do
    case Client.request(:post, "/getChatMemberCount", Map.put(opts, :json, %{chat_id: chat_id})) do
      {:ok, %{"result" => count}} ->
        score = min(count / 1000.0 * 100, 100.0)
        {:ok, %{member_count: count, engagement_score: Float.round(score, 2), status: "success"}}
      {:error, reason} -> {:error, "Failed: #{inspect(reason)}"}
    end
  end

  defp build_opts(input) do
    case Map.get(input, :token) do
      nil -> %{}
      token -> %{token: token}
    end
  end
end
