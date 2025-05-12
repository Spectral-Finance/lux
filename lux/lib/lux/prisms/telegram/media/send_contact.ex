defmodule Lux.Prisms.Telegram.Media.SendContact do
  @moduledoc """
  A prism for sending contacts via the Telegram Bot API.

  This prism provides a simple interface to send contact information to Telegram chats.
  It uses the Telegram Bot API to send phone number and name information.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /sendContact
  - Supports required parameters (chat_id, phone_number, first_name) and optional parameters
  - Returns the sent message data on success
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Send a contact with required parameters
      iex> SendContact.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   phone_number: "+1_234_567_890",
      ...>   first_name: "John"
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 42, chat_id: 123_456_789}}

      # Send a contact with all optional parameters
      iex> SendContact.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   phone_number: "+1_234_567_890",
      ...>   first_name: "John",
      ...>   last_name: "Doe",
      ...>   vcard: "BEGIN:VCARD\\nVERSION:3.0\\nFN:John Doe\\nTEL:+1_234_567_890\\nEND:VCARD"
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 42, chat_id: 123_456_789}}
  """

  use Lux.Prism,
    name: "Send Telegram Contact",
    description: "Sends contact information via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        phone_number: %{
          type: :string,
          description: "Contact's phone number"
        },
        first_name: %{
          type: :string,
          description: "Contact's first name"
        },
        last_name: %{
          type: :string,
          description: "Contact's last name"
        },
        vcard: %{
          type: :string,
          description: "Additional data about the contact in the form of a vCard, 0-2048 bytes"
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
        },
        plug: %{
          type: :object,
          description: "Additional plug parameters"
        }
      },
      required: ["chat_id", "phone_number", "first_name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{
          type: :boolean,
          description: "Whether the contact was successfully sent"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the sent message"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Identifier of the target chat"
        }
      },
      required: ["sent", "message_id"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to send a contact to a Telegram chat.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, phone_number} <- validate_param(params, :phone_number),
         {:ok, first_name} <- validate_param(params, :first_name) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} sending contact to chat #{chat_id}")

      # Build the request body with validated parameters
      request_body = params
      |> Map.take([:chat_id, :phone_number, :first_name, :last_name,
                   :vcard, :disable_notification, :protect_content,
                   :reply_to_message_id, :allow_sending_without_reply,
                   :reply_markup])
      |> Map.merge(%{
        chat_id: chat_id,
        phone_number: phone_number,
        first_name: first_name
      })

      # Prepare request options
      request_opts = %{json: request_body}
      |> Map.merge(Map.take(params, [:plug]))

      case Client.request(:post, "/sendContact", request_opts) do
        {:ok, %{"result" => result}} when is_map(result) ->
          Logger.info("Successfully sent contact to chat #{chat_id}")

          {:ok, %{
            sent: true,
            message_id: result["message_id"],
            chat_id: chat_id
          }}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to send contact: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to send contact: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to send contact: #{inspect(error)}"}
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
end
