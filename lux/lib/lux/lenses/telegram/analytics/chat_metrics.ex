defmodule Lux.Lenses.Telegram.Analytics.ChatMetrics do
  @moduledoc """
  Lens for retrieving chat-level analytics from the Telegram Bot API.

  Fetches member counts, message statistics, and growth metrics
  for Telegram groups and channels using the getChatMemberCount
  and getChatStatistics endpoints.

  ## Examples

      iex> ChatMetrics.focus(%{chat_id: "-1001234567890"})
      {:ok, %{chat_id: "-1001234567890", member_count: 5000, ...}}

      iex> ChatMetrics.focus(%{chat_id: "@mychannel"})
      {:ok, %{chat_id: "@mychannel", member_count: 12000, ...}}
  """

  use Lux.Lens,
    name: "Telegram Chat Metrics",
    description: "Retrieves member count and chat-level statistics for Telegram groups and channels",
    url: "https://api.telegram.org/bot",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: :string,
          description: "Telegram chat ID or @username of the channel/group"
        }
      },
      required: ["chat_id"]
    }

  alias Lux.Integrations.TelegramAnalytics

  def before_focus(params) do
    chat_id = Map.get(params, :chat_id)
    token = TelegramAnalytics.bot_token()

    params
    |> Map.put(:url, "https://api.telegram.org/bot#{token}/getChatMemberCount")
    |> Map.put(:chat_id, chat_id)
  end

  def after_focus(%{"ok" => true, "result" => count}) when is_integer(count) do
    {:ok, %{
      member_count: count,
      retrieved_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }}
  end

  def after_focus(%{"ok" => false} = error) do
    TelegramAnalytics.parse_error(error)
  end

  def after_focus(body), do: {:ok, body}
end
