defmodule Lux.Lenses.Telegram.Messaging.ListUpdates do
  @moduledoc """
  A lens for listing updates from Telegram (getUpdates).
  """

  alias Lux.Integrations.Telegram.Client

  use Lux.Lens,
    name: "List Telegram Updates",
    description: "Lists updates from Telegram (incoming messages, etc.)",
    url: "https://api.telegram.org/bot/:token/getUpdates",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        offset: %{type: :integer, description: "Identifier of the first update to be returned"},
        limit: %{type: :integer, description: "Limits the number of updates to be retrieved (1-100)", default: 100},
        timeout: %{type: :integer, description: "Timeout in seconds for long polling", default: 0},
        allowed_updates: %{
          type: :array,
          description: "List of update types to receive",
          items: %{type: :string}
        }
      }
    }

  @impl true
  def focus(params) do
    query = build_query(params)

    case Client.request(:get, "/getUpdates#{query}") do
      {:ok, %{"result" => updates}} ->
        {:ok, Enum.map(updates, &format_update/1)}

      {:error, {status, description}} ->
        {:error, %{status: status, description: description}}

      {:error, error} ->
        {:error, %{error: inspect(error)}}
    end
  end

  defp build_query(params) do
    params
    |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
    |> case do
      [] -> ""
      parts -> "?#{Enum.join(parts, "&")}"
    end
  end

  defp format_update(update) do
    %{
      update_id: update["update_id"],
      message: format_message(update["message"]),
      edited_message: format_message(update["edited_message"]),
      callback_query: format_callback_query(update["callback_query"])
    }
  end

  defp format_message(nil), do: nil
  defp format_message(message) do
    %{
      message_id: message["message_id"],
      text: message["text"],
      date: message["date"],
      chat: %{
        id: message["chat"]["id"],
        type: message["chat"]["type"],
        title: message["chat"]["title"]
      },
      from: format_user(message["from"])
    }
  end

  defp format_callback_query(nil), do: nil
  defp format_callback_query(query) do
    %{
      id: query["id"],
      data: query["data"],
      message: format_message(query["message"])
    }
  end

  defp format_user(nil), do: nil
  defp format_user(user) do
    %{
      id: user["id"],
      username: user["username"],
      first_name: user["first_name"],
      is_bot: user["is_bot"]
    }
  end
end
