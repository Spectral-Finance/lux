defmodule Lux.Prisms.Telegram.Interactive.StopPoll do
  @moduledoc """
  A prism for stopping polls via the Telegram Bot API.

  This prism provides a simple interface to stop active polls in Telegram chats.
  It uses the Telegram Bot API to close polls and prevent further voting.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /stopPoll
  - Supports required parameters (chat_id, message_id)
  - Returns the final poll state with voting results
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Stop a poll
      iex> StopPoll.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   message_id: 42
      ...> }, %{name: "Agent"})
      {:ok, %{
        stopped: true,
        poll_id: "poll123456",
        message_id: 42,
        chat_id: 123_456_789,
        total_voter_count: 11,
        is_closed: true,
        options: [
          %{"text" => "Red", "voter_count" => 3},
          %{"text" => "Green", "voter_count" => 2},
          %{"text" => "Blue", "voter_count" => 5},
          %{"text" => "Yellow", "voter_count" => 1}
        ]
      }}
  """

  use Lux.Prism,
    name: "Stop Telegram Poll",
    description: "Stops a poll via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the message with the poll"
        }
      },
      required: ["chat_id", "message_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        stopped: %{
          type: :boolean,
          description: "Whether the poll was successfully stopped"
        },
        poll_id: %{
          type: :string,
          description: "Unique poll identifier"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the message with the poll"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Identifier of the target chat"
        },
        question: %{
          type: :string,
          description: "The poll question"
        },
        options: %{
          type: :array,
          description: "List of poll options with voting results"
        },
        total_voter_count: %{
          type: :integer,
          description: "Total number of users that voted in the poll"
        },
        is_closed: %{
          type: :boolean,
          description: "True, if the poll is closed"
        }
      },
      required: ["stopped", "poll_id"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to stop a poll in a Telegram chat.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, message_id} <- validate_param(params, :message_id, :integer) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} stopping poll in message #{message_id} in chat #{chat_id}")

      # Build the request body
      request_body = Map.take(params, [:chat_id, :message_id])

      # Prepare request options
      request_opts = %{json: request_body}

      case Client.request(:post, "/stopPoll", request_opts) do
        {:ok, %{"result" => poll}} when is_map(poll) ->
          Logger.info("Successfully stopped poll in chat #{chat_id}")

          {:ok, %{
            stopped: true,
            poll_id: poll["id"],
            message_id: message_id,
            chat_id: chat_id,
            question: poll["question"],
            options: poll["options"],
            total_voter_count: poll["total_voter_count"],
            is_closed: poll["is_closed"]
          }}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to stop poll: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to stop poll: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to stop poll: #{inspect(error)}"}
      end
    end
  end

  defp validate_param(params, key, type \\ :any) do
    case Map.fetch(params, key) do
      {:ok, value} when type == :integer and is_integer(value) -> {:ok, value}
      {:ok, value} when type == :any and is_integer(value) -> {:ok, value}
      {:ok, value} when type == :any and is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
