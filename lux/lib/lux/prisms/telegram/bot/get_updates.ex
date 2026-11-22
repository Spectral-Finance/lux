defmodule Lux.Prisms.Telegram.Bot.GetUpdates do
  @moduledoc """
  A prism for receiving incoming updates via long polling (Telegram Bot API).

  Use this prism to receive messages, edited messages, channel posts, callback queries
  and other updates when a webhook is NOT configured. After processing updates, pass the
  returned `update_id` (or the highest one) as `offset` on the next call to confirm them.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /getUpdates
  - Supports optional parameters (offset, limit, timeout, allowed_updates)
  - Returns the list of raw update objects exactly as delivered by Telegram
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      GetUpdates.handler(%{timeout: 0}, %{name: "Agent"})
      #=> {:ok, %{updates: [%{"update_id" => 100, "message" => %{"text" => "hi"}}], count: 1}}

      # Confirm previous updates and only receive message updates
      GetUpdates.handler(%{offset: 101, allowed_updates: ["message"]}, %{name: "Agent"})
      #=> {:ok, %{updates: [], count: 0}}
  """

  use Lux.Prism,
    name: "Get Telegram Updates",
    description: "Receives incoming updates via long polling using the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        offset: %{
          type: :integer,
          description: "Identifier of the first update to be returned. Must be greater by one than the highest among the identifiers of previously received updates."
        },
        limit: %{
          type: :integer,
          description: "Limits the number of updates to be retrieved. Values between 1-100 are accepted."
        },
        timeout: %{
          type: :integer,
          description: "Timeout in seconds for long polling. Defaults to 0, i.e. a short poll."
        },
        allowed_updates: %{
          type: :array,
          description: "A JSON-serialized list of the update types you want your bot to receive (e.g. [\"message\", \"callback_query\"])."
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        updates: %{
          type: :array,
          description: "The list of update objects returned by Telegram"
        },
        count: %{
          type: :integer,
          description: "Number of updates returned"
        }
      },
      required: ["updates", "count"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to fetch updates from Telegram.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns the raw list of updates plus a convenience count
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} fetching updates (getUpdates)")

    request_body =
      Map.take(params, [:offset, :limit, :timeout, :allowed_updates])

    case Client.request(:post, "/getUpdates", %{json: request_body}) do
      {:ok, %{"result" => updates}} when is_list(updates) ->
        Logger.info("Received #{length(updates)} update(s) from Telegram")
        {:ok, %{updates: updates, count: length(updates)}}

      {:error, {status, %{"description" => description}}} ->
        {:error, "Failed to get updates: #{description} (HTTP #{status})"}

      {:error, {status, description}} when is_binary(description) ->
        {:error, "Failed to get updates: #{description} (HTTP #{status})"}

      {:error, error} ->
        {:error, "Failed to get updates: #{inspect(error)}"}
    end
  end
end