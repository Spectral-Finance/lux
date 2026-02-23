defmodule Lux.Lenses.Telegram.Updates.GetUpdates do
  @moduledoc """
  A lens for retrieving incoming updates from the Telegram Bot API.

  Uses long polling to receive updates. Each update has a unique identifier
  which can be used to acknowledge it (by passing offset = update_id + 1).

  ## Examples

      iex> GetUpdates.focus(%{}, %{})
      {:ok, [
        %{
          update_id: 123456789,
          message: %{
            message_id: 42,
            chat: %{id: 987654321},
            text: "Hello bot!"
          }
        }
      ]}

      iex> GetUpdates.focus(%{offset: 123456790, limit: 10, timeout: 30}, %{})
      {:ok, []}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram Updates",
    description: "Retrieves incoming updates via long polling from the Telegram Bot API",
    url: "https://api.telegram.org/bot/getUpdates",
    method: :get,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        offset: %{
          type: :integer,
          description: "Identifier of the first update to be returned. Set to last update_id + 1 to acknowledge previous updates."
        },
        limit: %{
          type: :integer,
          description: "Limits the number of updates to be retrieved (1-100). Defaults to 100."
        },
        timeout: %{
          type: :integer,
          description: "Timeout in seconds for long polling. Defaults to 0 (short poll)."
        },
        allowed_updates: %{
          type: :array,
          items: %{type: :string},
          description: "List of update types to receive (e.g. [\"message\", \"callback_query\"])."
        }
      }
    }

  @impl true
  def before_focus(params) do
    query =
      params
      |> Map.take(["offset", "limit", "timeout", "allowed_updates",
                   :offset, :limit, :timeout, :allowed_updates])
      |> Enum.reduce(%{}, fn {k, v}, acc ->
        Map.put(acc, to_string(k), v)
      end)

    {:ok, query}
  end

  @impl true
  def after_focus(%{"ok" => true, "result" => updates}) when is_list(updates) do
    {:ok, Enum.map(updates, &format_update/1)}
  end

  def after_focus(%{"ok" => false, "description" => description}) do
    {:error, description}
  end

  def after_focus(response) do
    {:error, response}
  end

  defp format_update(update) do
    %{
      update_id: update["update_id"],
      message: format_message(update["message"]),
      edited_message: format_message(update["edited_message"]),
      callback_query: update["callback_query"],
      inline_query: update["inline_query"],
      channel_post: format_message(update["channel_post"])
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp format_message(nil), do: nil

  defp format_message(msg) do
    %{
      message_id: msg["message_id"],
      chat: msg["chat"],
      from: msg["from"],
      date: msg["date"],
      text: msg["text"],
      entities: msg["entities"],
      photo: msg["photo"],
      document: msg["document"],
      voice: msg["voice"],
      caption: msg["caption"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
