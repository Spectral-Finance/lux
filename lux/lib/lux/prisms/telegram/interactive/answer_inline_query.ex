defmodule Lux.Prisms.Telegram.Interactive.AnswerInlineQuery do
  @moduledoc """
  A prism for answering inline queries via the Telegram Bot API.

  This prism provides a simple interface to respond to inline queries from Telegram users.
  It uses the Telegram Bot API to send a set of results that will appear to the user who sent the inline query.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /answerInlineQuery
  - Supports required parameters (inline_query_id, results) and optional parameters
  - Returns a simple success response on successful answering
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Answer an inline query with basic results
      iex> AnswerInlineQuery.handler(%{
      ...>   inline_query_id: "123456789",
      ...>   results: [
      ...>     %{
      ...>       type: "article",
      ...>       id: "1",
      ...>       title: "Result 1",
      ...>       input_message_content: %{
      ...>         message_text: "This is result 1"
      ...>       }
      ...>     },
      ...>     %{
      ...>       type: "article",
      ...>       id: "2",
      ...>       title: "Result 2",
      ...>       input_message_content: %{
      ...>         message_text: "This is result 2"
      ...>       }
      ...>     }
      ...>   ]
      ...> }, %{name: "Agent"})
      {:ok, %{answered: true, inline_query_id: "123456789"}}

      # Answer an inline query with caching
      iex> AnswerInlineQuery.handler(%{
      ...>   inline_query_id: "123456789",
      ...>   results: [
      ...>     %{
      ...>       type: "article",
      ...>       id: "1",
      ...>       title: "Result 1",
      ...>       input_message_content: %{
      ...>         message_text: "This is result 1"
      ...>       }
      ...>     }
      ...>   ],
      ...>   cache_time: 300,
      ...>   is_personal: true
      ...> }, %{name: "Agent"})
      {:ok, %{answered: true, inline_query_id: "123456789"}}
  """

  use Lux.Prism,
    name: "Answer Telegram Inline Query",
    description: "Responds to inline queries from Telegram users",
    input_schema: %{
      type: :object,
      properties: %{
        inline_query_id: %{
          type: :string,
          description: "Unique identifier for the answered query"
        },
        results: %{
          type: :array,
          description: "A JSON-serialized array of results for the inline query"
        },
        cache_time: %{
          type: :integer,
          description: "The maximum amount of time in seconds that the result of the inline query may be cached on the server"
        },
        is_personal: %{
          type: :boolean,
          description: "Pass True if results may be cached on the server side only for the user that sent the query"
        },
        next_offset: %{
          type: :string,
          description: "Pass the offset that a client should send in the next query with the same text to receive more results"
        },
        button: %{
          type: :object,
          description: "A JSON-serialized object describing a button to be shown above inline query results"
        }
      },
      required: ["inline_query_id", "results"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        answered: %{
          type: :boolean,
          description: "Whether the inline query was successfully answered"
        },
        inline_query_id: %{
          type: :string,
          description: "Identifier of the answered inline query"
        }
      },
      required: ["answered", "inline_query_id"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to answer an inline query from a Telegram user.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    # Validate inline_query_id
    inline_query_id_result = case Map.fetch(params, :inline_query_id) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      {:ok, value} when is_integer(value) -> {:ok, to_string(value)}
      _ -> {:error, "Missing or invalid inline_query_id"}
    end

    # Validate results
    results_result = case Map.fetch(params, :results) do
      {:ok, value} when is_list(value) and value != [] -> {:ok, value}
      _ -> {:error, "Missing or invalid results"}
    end

    with {:ok, inline_query_id} <- inline_query_id_result,
         {:ok, _results} <- results_result do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} answering inline query #{inline_query_id}")

      # Build the request body
      request_body = Map.take(params, [:inline_query_id, :results, :cache_time,
                              :is_personal, :next_offset, :button])

      # Ensure results is properly formatted as JSON string if not already
      request_body = if is_list(request_body[:results]) do
        # Convert results to JSON string
        Map.update!(request_body, :results, &Jason.encode!/1)
      else
        request_body
      end

      # Prepare request options
      request_opts = %{json: request_body}

      case Client.request(:post, "/answerInlineQuery", request_opts) do
        {:ok, %{"result" => true}} ->
          Logger.info("Successfully answered inline query #{inline_query_id}")
          {:ok, %{
            answered: true,
            inline_query_id: inline_query_id
          }}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to answer inline query: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to answer inline query: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to answer inline query: #{inspect(error)}"}
      end
    end
  end
end
