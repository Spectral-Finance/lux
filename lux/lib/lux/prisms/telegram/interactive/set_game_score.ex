defmodule Lux.Prisms.Telegram.Interactive.SetGameScore do
  @moduledoc """
  A prism for setting game scores via the Telegram Bot API.

  This prism provides a simple interface to set scores in Telegram games.
  It uses the Telegram Bot API to update scores for users playing games on Telegram.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /setGameScore
  - Supports required parameters (user_id, score) and optional parameters
  - Supports both chat messages and inline messages
  - Returns success status and score information
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Set a game score for a user in a chat message
      iex> SetGameScore.handler(%{
      ...>   user_id: 123_456_789,
      ...>   score: 100,
      ...>   chat_id: 987_654_321,
      ...>   message_id: 42
      ...> }, %{name: "Agent"})
      {:ok, %{set: true, user_id: 123_456_789, score: 100, chat_id: 987_654_321, message_id: 42}}

      # Set a game score for a user in an inline message
      iex> SetGameScore.handler(%{
      ...>   user_id: 123_456_789,
      ...>   score: 100,
      ...>   inline_message_id: "ABCDEF123456"
      ...> }, %{name: "Agent"})
      {:ok, %{set: true, user_id: 123_456_789, score: 100, inline_message_id: "ABCDEF123456"}}

      # Set a game score with force flag (allowing score to decrease)
      iex> SetGameScore.handler(%{
      ...>   user_id: 123_456_789,
      ...>   score: 50,
      ...>   chat_id: 987_654_321,
      ...>   message_id: 42,
      ...>   force: true
      ...> }, %{name: "Agent"})
      {:ok, %{set: true, user_id: 123_456_789, score: 50, chat_id: 987_654_321, message_id: 42, force: true}}
  """

  use Lux.Prism,
    name: "Set Telegram Game Score",
    description: "Sets the score of a user in a Telegram game",
    input_schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :integer,
          description: "User identifier"
        },
        score: %{
          type: :integer,
          description: "New score, must be non-negative"
        },
        force: %{
          type: :boolean,
          description: "Pass True if the high score is allowed to decrease. This can be useful when fixing mistakes or banning cheaters"
        },
        disable_edit_message: %{
          type: :boolean,
          description: "Pass True if the game message should not be automatically edited to include the current scoreboard"
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
      required: ["user_id", "score"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        set: %{
          type: :boolean,
          description: "Whether the score was successfully set"
        },
        user_id: %{
          type: :integer,
          description: "User identifier"
        },
        score: %{
          type: :integer,
          description: "New score value"
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
        force: %{
          type: :boolean,
          description: "Whether force flag was used"
        }
      },
      required: ["set", "user_id", "score"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to set the score of a user in a Telegram game.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, user_id} <- validate_param(params, :user_id, :integer),
         {:ok, score} <- validate_param(params, :score, :integer) do

      # Validate that we have either (chat_id and message_id) or inline_message_id
      case validate_message_identifiers(params) do
        :ok ->
          agent_name = agent[:name] || "Unknown Agent"
          Logger.info("Agent #{agent_name} setting game score #{score} for user #{user_id}")

          # Build the request body
          request_body = Map.take(params, [:user_id, :score, :force, :disable_edit_message,
                                  :chat_id, :message_id, :inline_message_id])

          # Prepare request options
          request_opts = %{json: request_body}

          case Client.request(:post, "/setGameScore", request_opts) do
            {:ok, %{"result" => result}} ->
              # Build response based on result and params
              response = build_response(params, result)
              Logger.info("Successfully set game score #{score} for user #{user_id}")
              {:ok, response}

            {:error, {status, %{"description" => description}}} ->
              {:error, "Failed to set game score: #{description} (HTTP #{status})"}

            {:error, {status, description}} when is_binary(description) ->
              {:error, "Failed to set game score: #{description} (HTTP #{status})"}

            {:error, error} ->
              {:error, "Failed to set game score: #{inspect(error)}"}
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

  defp build_response(params, _result) do
    # Base response with required fields
    base_response = %{
      set: true,
      user_id: params.user_id,
      score: params.score
    }

    # Add optional fields based on what was provided in the request
    response =
      if Map.has_key?(params, :inline_message_id) do
        Map.put(base_response, :inline_message_id, params.inline_message_id)
      else
        base_response
        |> Map.put(:chat_id, params.chat_id)
        |> Map.put(:message_id, params.message_id)
      end

    # Add force flag if it was provided
    if Map.has_key?(params, :force) do
      Map.put(response, :force, params.force)
    else
      response
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
