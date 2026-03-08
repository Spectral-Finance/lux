defmodule Lux.Lenses.Telegram.GetBotMetrics do
  @moduledoc """
  Lens for retrieving real-time bot metrics from the Telegram API.
  Fetches webhook info and bot metadata.
  """

  alias Lux.Integrations.Telegram.Client

  def focus(params, _opts \\ []) do
    token = params[:token] || params["token"] || ""
    plug = params[:plug] || params["plug"]
    action = params[:action] || params["action"] || "webhook_info"

    case action do
      "webhook_info" -> get_webhook_info(token, plug)
      "bot_info" -> get_bot_info(token, plug)
      _ -> {:error, "Unknown action: #{action}"}
    end
  end

  defp get_webhook_info(token, plug) do
    case Client.request(:post, "/getWebhookInfo", %{token: token, json: %{}, plug: plug}) do
      {:ok, %{"result" => info}} ->
        {:ok, %{
          url: info["url"],
          has_custom_certificate: info["has_custom_certificate"],
          pending_update_count: info["pending_update_count"],
          last_error_date: info["last_error_date"],
          last_error_message: info["last_error_message"],
          max_connections: info["max_connections"],
          ip_address: info["ip_address"]
        }}
      {:ok, info} when is_map(info) -> {:ok, info}
      error -> error
    end
  end

  defp get_bot_info(token, plug) do
    case Client.request(:post, "/getMe", %{token: token, json: %{}, plug: plug}) do
      {:ok, %{"result" => bot}} ->
        {:ok, %{
          id: bot["id"],
          username: bot["username"],
          first_name: bot["first_name"],
          can_join_groups: bot["can_join_groups"],
          can_read_all_group_messages: bot["can_read_all_group_messages"],
          supports_inline_queries: bot["supports_inline_queries"]
        }}
      {:ok, bot} -> {:ok, bot}
      error -> error
    end
  end
end
