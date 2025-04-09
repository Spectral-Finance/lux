defmodule Lux.Prisms.Telegram.Interactive.SendPoll do
  @moduledoc """
  A prism for sending polls via the Telegram Bot API.

  This prism provides a simple interface to send polls to Telegram chats.
  It uses the Telegram Bot API to create and send interactive polls with various options.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /sendPoll
  - Supports required parameters (chat_id, question, options) and optional parameters
  - Returns the sent poll data on success
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Send a regular poll
      iex> SendPoll.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   question: "What is your favorite color?",
      ...>   options: ["Red", "Green", "Blue"]
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 42, chat_id: 123_456_789, question: "What is your favorite color?"}}

      # Send a quiz with correct answer
      iex> SendPoll.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   question: "What is the capital of France?",
      ...>   options: ["London", "Paris", "Berlin"],
      ...>   type: "quiz",
      ...>   correct_option_id: 1,
      ...>   explanation: "Paris is the capital of France"
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 42, chat_id: 123_456_789, question: "What is the capital of France?"}}

      # Send a poll with multiple answers allowed
      iex> SendPoll.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   question: "Select all fruits from the list:",
      ...>   options: ["Apple", "Carrot", "Banana", "Potato"],
      ...>   allows_multiple_answers: true
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 42, chat_id: 123_456_789, question: "Select all fruits from the list:"}}
  """

  use Lux.Prism,
    name: "Send Telegram Poll",
    description: "Sends polls via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        question: %{
          type: :string,
          description: "Poll question, 1-300 characters"
        },
        options: %{
          type: :array,
          description: "A list of answer options, 2-10 strings 1-100 characters each"
        },
        is_anonymous: %{
          type: :boolean,
          description: "True, if the poll needs to be anonymous, defaults to True"
        },
        type: %{
          type: :string,
          description: "Poll type, 'quiz' or 'regular', defaults to 'regular'",
          enum: ["quiz", "regular"]
        },
        allows_multiple_answers: %{
          type: :boolean,
          description: "True, if the poll allows multiple answers, ignored for quizzes"
        },
        correct_option_id: %{
          type: :integer,
          description: "0-based index of the correct answer option, required for quizzes"
        },
        explanation: %{
          type: :string,
          description: "Text that is shown when a user chooses an incorrect answer in a quiz"
        },
        explanation_parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the explanation",
          enum: ["Markdown", "MarkdownV2", "HTML"]
        },
        open_period: %{
          type: :integer,
          description: "Amount of time in seconds the poll will be active after creation"
        },
        close_date: %{
          type: :integer,
          description: "Unix timestamp when the poll will be automatically closed"
        },
        is_closed: %{
          type: :boolean,
          description: "Pass True if the poll needs to be immediately closed"
        },
        disable_notification: %{
          type: :boolean,
          description: "Sends the message silently. Users will receive a notification with no sound"
        },
        protect_content: %{
          type: :boolean,
          description: "Protects the contents of the sent message from forwarding and saving"
        },
        reply_to_message_id: %{
          type: :integer,
          description: "If the message is a reply, ID of the original message"
        },
        allow_sending_without_reply: %{
          type: :boolean,
          description: "Pass True if the message should be sent even if the specified replied-to message is not found"
        },
        reply_markup: %{
          type: :object,
          description: "Additional interface options. A JSON-serialized object for an inline keyboard, custom reply keyboard, instructions to remove reply keyboard or to force a reply from the user"
        }
      },
      required: ["chat_id", "question", "options"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{
          type: :boolean,
          description: "Whether the poll was successfully sent"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the sent message"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Identifier of the target chat"
        },
        question: %{
          type: :string,
          description: "The poll question"
        },
        poll_id: %{
          type: :string,
          description: "Unique poll identifier"
        },
        options: %{
          type: :array,
          description: "List of poll options"
        },
        total_voter_count: %{
          type: :integer,
          description: "Total number of users that voted in the poll"
        },
        is_anonymous: %{
          type: :boolean,
          description: "True, if the poll is anonymous"
        },
        type: %{
          type: :string,
          description: "Poll type, 'quiz' or 'regular'"
        },
        allows_multiple_answers: %{
          type: :boolean,
          description: "True, if the poll allows multiple answers"
        },
        is_closed: %{
          type: :boolean,
          description: "True, if the poll is closed"
        },
        open_period: %{
          type: :integer,
          description: "Amount of time the poll is active in seconds"
        }
      },
      required: ["sent", "message_id", "question"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to send a poll to a Telegram chat.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, question} <- validate_param(params, :question),
         {:ok, _options} <- validate_options(params) do

      # Validate quiz-specific parameters if applicable
      with :ok <- validate_quiz_params(params) do
        agent_name = agent[:name] || "Unknown Agent"
        Logger.info("Agent #{agent_name} sending poll to chat #{chat_id}")

        # Build the request body
        request_body = Map.take(params, [:chat_id, :question, :options, :is_anonymous,
                                :type, :allows_multiple_answers, :correct_option_id,
                                :explanation, :explanation_parse_mode, :open_period,
                                :close_date, :is_closed, :disable_notification,
                                :protect_content, :reply_to_message_id,
                                :allow_sending_without_reply, :reply_markup])

        # Prepare request options
        request_opts = %{json: request_body}

        case Client.request(:post, "/sendPoll", request_opts) do
          {:ok, %{"result" => result}} when is_map(result) ->
            Logger.info("Successfully sent poll to chat #{chat_id}")

            poll = result["poll"]

            response = %{
              sent: true,
              message_id: result["message_id"],
              chat_id: chat_id,
              question: question,
              poll_id: poll["id"],
              options: poll["options"],
              total_voter_count: poll["total_voter_count"],
              is_anonymous: poll["is_anonymous"],
              type: poll["type"],
              allows_multiple_answers: poll["allows_multiple_answers"],
              is_closed: poll["is_closed"]
            }

            # Add optional fields if they exist
            response = if Map.has_key?(poll, "open_period"), do: Map.put(response, :open_period, poll["open_period"]), else: response

            {:ok, response}

          {:error, {status, %{"description" => description}}} ->
            {:error, "Failed to send poll: #{description} (HTTP #{status})"}

          {:error, {status, description}} when is_binary(description) ->
            {:error, "Failed to send poll: #{description} (HTTP #{status})"}

          {:error, error} ->
            {:error, "Failed to send poll: #{inspect(error)}"}
        end
      end
    end
  end

  defp validate_param(params, key, _type \\ :any) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      {:ok, value} when is_integer(value) -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_options(params) do
    case Map.fetch(params, :options) do
      {:ok, options} when is_list(options) and length(options) >= 2 and length(options) <= 10 ->
        # Verify all options are valid (either non-empty strings or maps with text field)
        if Enum.all?(options, fn option ->
          (is_binary(option) and String.length(option) > 0 and String.length(option) <= 100) or
          (is_map(option) and is_binary(option[:text]) and String.length(option[:text]) > 0 and String.length(option[:text]) <= 100)
        end) do
          # Transform any map options to their text value
          formatted_options = Enum.map(options, fn
            option when is_binary(option) -> option
            option when is_map(option) -> option[:text]
          end)
          {:ok, formatted_options}
        else
          {:error, "All poll options must be non-empty strings or maps with text field, 1-100 characters each"}
        end
      {:ok, options} when is_list(options) and length(options) < 2 ->
        {:error, "Options must contain at least 2 items"}
      {:ok, options} when is_list(options) and length(options) > 10 ->
        {:error, "Options cannot contain more than 10 items"}
      {:ok, _} ->
        {:error, "Options must be a list containing 2-10 items"}
      _ ->
        {:error, "Missing or invalid options"}
    end
  end

  defp validate_quiz_params(params) do
    if Map.get(params, :type) == "quiz" do
      case Map.fetch(params, :correct_option_id) do
        {:ok, correct_option_id} when is_integer(correct_option_id) ->
          options = Map.get(params, :options, [])
          if correct_option_id >= 0 and correct_option_id < length(options) do
            :ok
          else
            {:error, "correct_option_id must be a valid index in the options array"}
          end
        _ ->
          {:error, "Quiz polls must have a correct_option_id specified"}
      end
    else
      :ok
    end
  end
end
