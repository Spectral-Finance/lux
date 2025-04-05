defmodule Lux.Prisms.Discord.Messages.SendMessage do
  @moduledoc """
  A prism for sending messages to Discord channels.

  This prism provides a simple interface for sending Discord messages with:
  - Minimal required parameters (channel_id, content)
  - Direct Discord API error propagation
  - Simple success/failure response structure

  ## Examples
      iex> SendMessage.handler(%{
      ...>   channel_id: "123456789",
      ...>   content: "Hello, Discord!"
      ...> }, %{name: "Agent"})
      {:ok, %{
        sent: true,
        message_id: "111111111111111111",
        content: "Hello, Discord!",
        channel_id: "123456789"
      }}
  """

  use Lux.Prism,
    name: "Send Discord Message",
    description: "Sends a message to a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to send the message to",
          pattern: "^[0-9]{17,20}$"
        },
        content: %{
          type: :string,
          description: "The message content to send",
          minLength: 1,
          maxLength: 2000
        }
      },
      required: ["channel_id", "content"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{
          type: :boolean,
          description: "Whether the message was successfully sent"
        },
        message_id: %{
          type: :string,
          description: "The ID of the sent message"
        },
        content: %{
          type: :string,
          description: "The content of the sent message"
        },
        channel_id: %{
          type: :string,
          description: "The ID of the channel where the message was sent"
        }
      },
      required: ["sent"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to send a message to a Discord channel.

  Returns {:ok, %{sent: true, message_id: id, content: content, channel_id: channel_id}} on success.
  Returns {:error, {status, message}} on failure.
  """
  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, content} <- validate_param(params, :content) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} sending message to channel #{channel_id}: #{content}")

      Client.request(:post, "/channels/#{channel_id}/messages", %{json: %{content: content}})
      |> Client.handle_response(__MODULE__)
      |> case do
        {:ok, %{"id" => message_id}} ->
          {:ok, %{sent: true, message_id: message_id, content: content, channel_id: channel_id}}
        error -> error
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
