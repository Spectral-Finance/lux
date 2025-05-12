defmodule Lux.Prisms.Telegram.Interactive.GetGameHighScores do
  @moduledoc """
  A prism for retrieving game high scores via the Telegram Bot API.

  This prism provides a simple interface to get high scores for Telegram games.
  It uses the Telegram Bot API to retrieve game score data for a specific user and their neighbors.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /getGameHighScores
  - Supports required parameters (user_id) and optional parameters
  - Supports both chat messages and inline messages
  - Returns an array of high scores with user information
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Get high scores for a game in a chat message
      iex> GetGameHighScores.handler(%{
      ...>   user_id: 123_456_789,
      ...>   chat_id: 987_654_321,
      ...>   message_id: 42
      ...> }, %{name: "Agent"})
      {:ok, %{
      ...>   high_scores: [
      ...>     %{position: 1, score: 100, user: %{id: 123_456_789, first_name: "John"}},
      ...>     %{position: 2, score: 50, user: %{id: 987_654_321, first_name: "Mary"}}
      ...>   ],
      ...>   user_id: 123_456_789,
      ...>   chat_id: 987_654_321,
      ...>   message_id: 42
      ...> }}

      # Get high scores for a game in an inline message
      iex> GetGameHighScores.handler(%{
      ...>   user_id: 123_456_789,
      ...>   inline_message_id: "ABCDEF123456"
      ...> }, %{name: "Agent"})
      {:ok, %{
      ...>   high_scores: [
      ...>     %{position: 1, score: 100, user: %{id: 123_456_789, first_name: "John"}},
      ...>     %{position: 2, score: 50, user: %{id: 987_654_321, first_name: "Mary"}}
      ...>   ],
      ...>   user_id: 123_456_789,
      ...>   inline_message_id: "ABCDEF123456"
      ...> }}
  """

  use Lux.Prism,
    name: "Get Telegram Game High Scores",
    description: "Retrieves high scores for a Telegram game",
    input_schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :integer,
          description: "Target user identifier"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Required if inline_message_id is not specified. Unique identifier for the target chat"
        },
        message_id: %{
          type: :integer,
          description: "Required if inline_message_id is not specified. Identifier of the sent message"
        },
        inline_message_id: %{
          type: :string,
          description: "Required if chat_id and message_id are not specified. Identifier of the inline message"
        }
      },
      required: ["user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :integer,
          description: "Target user identifier"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Identifier of the chat (for chat messages)"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the message (for chat messages)"
        },
        inline_message_id: %{
          type: :string,
          description: "Identifier of the inline message (for inline messages)"
        },
        high_scores: %{
          type: :array,
          description: "List of game high scores",
          items: %{
            type: :object,
            properties: %{
              position: %{
                type: :integer,
                description: "Position in high score table for the game"
              },
              user: %{
                type: :object,
                description: "User who scored",
                properties: %{
                  id: %{
                    type: :integer,
                    description: "User identifier"
                  },
                  first_name: %{
                    type: :string,
                    description: "User's first name"
                  },
                  last_name: %{
                    type: :string,
                    description: "Optional. User's last name"
                  },
                  username: %{
                    type: :string,
                    description: "Optional. User's username"
                  }
                }
              },
              score: %{
                type: :integer,
                description: "Score"
              }
            }
          }
        }
      },
      required: ["user_id", "high_scores"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to get high scores for a Telegram game.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, user_id} <- validate_param(params, :user_id, :integer) do
      # Validate that we have either (chat_id and message_id) or inline_message_id
      case validate_message_identifiers(params) do
        :ok ->
          agent_name = agent[:name] || "Unknown Agent"
          Logger.info("Agent #{agent_name} getting game high scores for user #{user_id}")

          # Build the request body
          request_body = Map.take(params, [:user_id, :chat_id, :message_id, :inline_message_id])

          # Prepare request options
          request_opts = %{json: request_body}

          case Client.request(:post, "/getGameHighScores", request_opts) do
            {:ok, %{"result" => high_scores}} when is_list(high_scores) ->
              # Transform high scores to the expected format
              formatted_high_scores = format_high_scores(high_scores)

              # Build response based on params and high scores
              response = build_response(params, formatted_high_scores)
              Logger.info("Successfully retrieved game high scores for user #{user_id}")
              {:ok, response}

            {:error, {status, %{"description" => description}}} ->
              {:error, "Failed to get game high scores: #{description} (HTTP #{status})"}

            {:error, {status, description}} when is_binary(description) ->
              {:error, "Failed to get game high scores: #{description} (HTTP #{status})"}

            {:error, error} ->
              {:error, "Failed to get game high scores: #{inspect(error)}"}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp validate_message_identifiers(params) do
    cond do
      Map.has_key?(params, :inline_message_id) ->
        {:ok, _} = validate_param(params, :inline_message_id)
        :ok

      Map.has_key?(params, :chat_id) and Map.has_key?(params, :message_id) ->
        with {:ok, _} <- validate_param(params, :chat_id),
             {:ok, _} <- validate_param(params, :message_id, :integer) do
          :ok
        end

      true ->
        {:error, "Missing or invalid message identifier: Either (chat_id and message_id) or inline_message_id must be provided"}
    end
  end

  defp format_high_scores(high_scores) do
    Enum.with_index(high_scores, 1)
    |> Enum.map(fn {score, position} ->
      %{
        position: position,
        user: %{
          id: score["user"]["id"],
          first_name: score["user"]["first_name"],
          last_name: Map.get(score["user"], "last_name"),
          username: Map.get(score["user"], "username")
        },
        score: score["score"]
      }
    end)
  end

  defp build_response(params, high_scores) do
    # Base response with required fields
    base_response = %{
      user_id: params.user_id,
      high_scores: high_scores
    }

    # Add optional fields based on what was provided in the request
    if Map.has_key?(params, :inline_message_id) do
      Map.put(base_response, :inline_message_id, params.inline_message_id)
    else
      base_response
      |> Map.put(:chat_id, params.chat_id)
      |> Map.put(:message_id, params.message_id)
    end
  end

  defp validate_param(params, key, type \\ :any) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      {:ok, value} when is_integer(value) and type == :integer -> {:ok, value}
      {:ok, value} when is_integer(value) and type == :any -> {:ok, value}
      {:ok, _value} when type == :integer -> {:error, "#{key} must be an integer"}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
