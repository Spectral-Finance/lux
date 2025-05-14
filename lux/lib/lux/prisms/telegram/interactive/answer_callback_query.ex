defmodule Lux.Prisms.Telegram.Interactive.AnswerCallbackQuery do
  @moduledoc """
  A prism for answering callback queries via the Telegram Bot API.

  This prism provides a simple interface to respond to callback queries sent from inline keyboards.
  It uses the Telegram Bot API to send a notification to the user or update the message.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /answerCallbackQuery
  - Supports responding to callback queries with text, alerts, or URLs
  - Returns a simple success response
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Answer a callback query with a notification
      iex> AnswerCallbackQuery.handler(%{
      ...>   callback_query_id: "1234567890",
      ...>   text: "You clicked the button!"
      ...> }, %{name: "Agent"})
      {:ok, %{answered: true, callback_query_id: "1234567890"}}

      # Answer a callback query with an alert
      iex> AnswerCallbackQuery.handler(%{
      ...>   callback_query_id: "1234567890",
      ...>   text: "Important notification!",
      ...>   show_alert: true
      ...> }, %{name: "Agent"})
      {:ok, %{answered: true, callback_query_id: "1234567890"}}

      # Answer a callback query with a URL
      iex> AnswerCallbackQuery.handler(%{
      ...>   callback_query_id: "1234567890",
      ...>   url: "https://example.com/details"
      ...> }, %{name: "Agent"})
      {:ok, %{answered: true, callback_query_id: "1234567890"}}
  """

  use Lux.Prism,
    name: "Answer Telegram Callback Query",
    description: "Responds to callback queries from inline keyboards via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        callback_query_id: %{
          type: :string,
          description: "Unique identifier for the query to be answered"
        },
        text: %{
          type: :string,
          description: "Text of the notification. If not specified, nothing will be shown to the user, 0-200 characters"
        },
        show_alert: %{
          type: :boolean,
          description: "If true, an alert will be shown by the client instead of a notification at the top of the chat screen"
        },
        url: %{
          type: :string,
          description: "URL that will be opened by the user's client. If you have created a Game and accepted the conditions via @BotFather, you can specify a link to a Telegram mini-app"
        },
        cache_time: %{
          type: :integer,
          description: "The maximum amount of time in seconds that the result of the callback query may be cached client-side. Default is 0."
        }
      },
      required: ["callback_query_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        answered: %{
          type: :boolean,
          description: "Whether the callback query was successfully answered"
        },
        callback_query_id: %{
          type: :string,
          description: "Identifier of the answered callback query"
        }
      },
      required: ["answered", "callback_query_id"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to answer a callback query.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, callback_query_id} <- validate_callback_query_id(params) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} answering callback query #{callback_query_id}")

      # Build the request body
      request_body = Map.take(params, [:callback_query_id, :text, :show_alert, :url, :cache_time])

      # Prepare request options
      request_opts = %{json: request_body}

      case Client.request(:post, "/answerCallbackQuery", request_opts) do
        {:ok, %{"result" => true}} ->
          Logger.info("Successfully answered callback query #{callback_query_id}")
          {:ok, %{
            answered: true,
            callback_query_id: callback_query_id
          }}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to answer callback query: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to answer callback query: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to answer callback query: #{inspect(error)}"}
      end
    end
  end

  defp validate_callback_query_id(params) do
    case Map.fetch(params, :callback_query_id) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid callback_query_id"}
    end
  end
end
