defmodule Lux.Prisms.Telegram.TelegramAnalyticsPrism do
  @moduledoc """
  A prism for collecting Telegram bot message analytics.

  ## Example

      iex> Lux.Prisms.Telegram.TelegramAnalyticsPrism.handler(%{
      ...>   chat_id: 123456789,
      ...>   days: 7
      ...> }, %{})
  """

  use Lux.Prism,
    name: "Telegram Analytics",
    description: "Collects and analyzes Telegram bot message analytics",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: :integer, description: "Telegram chat ID"},
        days: %{type: :integer, description: "Days to analyze", default: 7},
        token: %{type: :string, description: "Bot token (optional)"}
      },
      required: ["chat_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        member_count: %{type: :integer},
        chat_info: %{type: :object},
        days_analyzed: %{type: :integer},
        status: %{type: :string}
      },
      required: ["status"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(input, _ctx) do
    input = Map.put_new(input, :days, 7)
    Logger.info("Fetching Telegram analytics for chat #{input.chat_id}")
    opts = build_opts(input)

    with {:ok, chat} <- get_chat(input.chat_id, opts),
         {:ok, count} <- get_member_count(input.chat_id, opts) do
      {:ok, %{
        chat_id: input.chat_id,
        chat_info: chat,
        member_count: count,
        days_analyzed: input.days,
        status: "success"
      }}
    end
  end

  defp get_chat(chat_id, opts) do
    case Client.request(:post, "/getChat", Map.put(opts, :json, %{chat_id: chat_id})) do
      {:ok, %{"result" => chat}} -> {:ok, chat}
      {:error, reason} -> {:error, "Failed to get chat: #{inspect(reason)}"}
    end
  end

  defp get_member_count(chat_id, opts) do
    case Client.request(:post, "/getChatMemberCount", Map.put(opts, :json, %{chat_id: chat_id})) do
      {:ok, %{"result" => count}} -> {:ok, count}
      {:error, _} -> {:ok, 0}
    end
  end

  defp build_opts(input) do
    case Map.get(input, :token) do
      nil -> %{}
      token -> %{token: token}
    end
  end
end
