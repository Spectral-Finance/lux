defmodule Lux.Lenses.Telegram.Messages.ReadUpdates do
  @moduledoc """
  A lens for receiving incoming updates via long polling from the Telegram Bot API.

  This lens provides a simple interface for fetching updates with:
  - Optional offset-based pagination
  - Configurable long polling timeout
  - Allowed update type filtering
  - Rate limit handling (429 responses)
  - Clean response structure

  ## Long Polling

  The `timeout` parameter controls how long the server will hold the connection
  open waiting for new updates. A value of 0 returns immediately.

  ## Update Types

  You can filter which update types to receive using `allowed_updates`:
  - message
  - edited_message
  - channel_post
  - callback_query
  - inline_query
  - and more

  ## Examples

      # Get latest updates
      iex> ReadUpdates.focus(%{})
      {:ok, [
        %{
          update_id: 123456789,
          message: %{
            message_id: 1,
            chat_id: 123456789,
            text: "Hello!"
          }
        }
      ]}

      # Long polling with offset
      iex> ReadUpdates.focus(%{
      ...>   offset: 123456790,
      ...>   timeout: 30,
      ...>   allowed_updates: ["message", "callback_query"]
      ...> })
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Read Telegram Updates",
    description: "Gets incoming updates via long polling from the Telegram Bot API",
    url: Telegram.api_url("getUpdates"),
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        offset: %{
          type: :integer,
          description: "Identifier of the first update to be returned. Must be greater by one than the highest among the identifiers of previously received updates."
        },
        limit: %{
          type: :integer,
          description: "Limits the number of updates to be retrieved (1-100, default 100)",
          minimum: 1,
          maximum: 100,
          default: 100
        },
        timeout: %{
          type: :integer,
          description: "Timeout in seconds for long polling (0 for short polling, default 0)",
          minimum: 0,
          default: 0
        },
        allowed_updates: %{
          type: :array,
          description: "List of update types to receive (e.g., [\"message\", \"callback_query\"])",
          items: %{type: :string}
        }
      },
      required: []
    }

  @doc """
  Transforms the Telegram API response into a clean format.

  Each update is normalized to include the update_id and the relevant payload
  (message, callback_query, etc.).
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => results}) when is_list(results) do
    updates = Enum.map(results, &normalize_update/1)
    {:ok, updates}
  end

  def after_focus(%{"ok" => false, "error_code" => 429, "parameters" => %{"retry_after" => retry_after}} = error) do
    {:error, %{
      reason: :rate_limited,
      retry_after: retry_after,
      description: error["description"]
    }}
  end

  def after_focus(%{"ok" => false, "description" => description, "error_code" => code}) do
    {:error, %{reason: :api_error, error_code: code, description: description}}
  end

  def after_focus(%{"description" => description}) do
    {:error, %{reason: :api_error, description: description}}
  end

  defp normalize_update(%{"update_id" => update_id} = update) do
    base = %{update_id: update_id}

    cond do
      msg = update["message"] ->
        Map.put(base, :message, %{
          message_id: msg["message_id"],
          chat_id: get_in(msg, ["chat", "id"]),
          text: msg["text"],
          from: normalize_user(msg["from"]),
          date: msg["date"]
        })

      cb = update["callback_query"] ->
        Map.put(base, :callback_query, %{
          id: cb["id"],
          from: normalize_user(cb["from"]),
          data: cb["data"],
          message_id: get_in(cb, ["message", "message_id"]),
          chat_id: get_in(cb, ["message", "chat", "id"])
        })

      edited = update["edited_message"] ->
        Map.put(base, :edited_message, %{
          message_id: edited["message_id"],
          chat_id: get_in(edited, ["chat", "id"]),
          text: edited["text"],
          from: normalize_user(edited["from"]),
          date: edited["date"],
          edit_date: edited["edit_date"]
        })

      post = update["channel_post"] ->
        Map.put(base, :channel_post, %{
          message_id: post["message_id"],
          chat_id: get_in(post, ["chat", "id"]),
          text: post["text"],
          date: post["date"]
        })

      true ->
        base
    end
  end

  defp normalize_user(nil), do: nil
  defp normalize_user(user) do
    %{
      id: user["id"],
      is_bot: user["is_bot"],
      first_name: user["first_name"],
      username: user["username"]
    }
  end
end
