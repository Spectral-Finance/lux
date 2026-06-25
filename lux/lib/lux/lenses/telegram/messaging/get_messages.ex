defmodule Lux.Lenses.Telegram.Messaging.GetMessages do
  @moduledoc """
  A lens for retrieving messages from a Telegram chat.

  This lens provides a simple interface for fetching message history
  from any Telegram chat (group, channel, or direct message) using
  the Bot API getUpdates or forwardMessage pattern.

  ## Examples

      iex> GetMessages.focus(%{
      ...>   chat_id: 123_456_789,
      ...>   limit: 20
      ...> })
      {:ok, %{messages: [...], count: 20}}
  """

  alias Lux.Integrations.Telegram.Client
  require Logger

  use Lux.Lens,
    name: "Get Telegram Messages",
    description: "Retrieves recent messages from a Telegram chat",
    url: "https://api.telegram.org/bot:token/getUpdates",
    method: :get,
    headers: [],
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat"
        },
        limit: %{
          type: :integer,
          description: "Maximum number of updates to retrieve (1-100)",
          minimum: 1,
          maximum: 100,
          default: 20
        },
        offset: %{
          type: :integer,
          description: "Identifier of the first update to return"
        }
      },
      required: ["chat_id"]
    }

  @impl true
  def focus(%{chat_id: chat_id} = params) do
    limit = Map.get(params, :limit, 20)
    offset = Map.get(params, :offset)

    query = %{chat_id: chat_id, limit: limit}
    query = if offset, do: Map.put(query, :offset, offset), else: query

    case Client.request(:get, "/getUpdates", %{params: query}) do
      {:ok, %{"result" => updates}} when is_list(updates) ->
        messages =
          updates
          |> Enum.filter(fn u -> Map.has_key?(u, "message") end)
          |> Enum.filter(fn u -> get_in(u, ["message", "chat", "id"]) == chat_id end)
          |> Enum.map(fn u -> parse_message(u["message"]) end)

        Logger.info("Retrieved #{length(messages)} messages from chat #{chat_id}")
        {:ok, %{messages: messages, count: length(messages), chat_id: chat_id}}

      {:error, {status, %{"description" => desc}}} ->
        {:error, "Telegram API error #{status}: #{desc}"}

      {:error, error} ->
        {:error, "Failed to get messages: #{inspect(error)}"}
    end
  end

  defp parse_message(msg) when is_map(msg) do
    %{
      message_id:  msg["message_id"],
      chat_id:     get_in(msg, ["chat", "id"]),
      from_id:     get_in(msg, ["from", "id"]),
      from_name:   get_in(msg, ["from", "first_name"]),
      username:    get_in(msg, ["from", "username"]),
      text:        msg["text"],
      date:        msg["date"],
      reply_to_id: get_in(msg, ["reply_to_message", "message_id"])
    }
  end
  defp parse_message(_), do: %{}
end
