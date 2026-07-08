defmodule Lux.Prisms.Discord.Messages.EditMessage do
  @moduledoc """
  A prism for editing messages in a Discord channel.

  This prism provides a simple interface for editing Discord messages with:
  - Minimal required parameters (channel_id, message_id, content)
  - Direct Discord API error propagation
  - Simple success/failure response structure

  ## Examples
      iex> EditMessage.handler(%{
      ...>   channel_id: "123456789",
      ...>   message_id: "987654321",
      ...>   content: "Updated message content"
      ...> }, %{name: "Test Agent"})
      {:ok, %{edited: true}}

      # Error handling
      iex> EditMessage.handler(%{
      ...>   channel_id: "invalid",
      ...>   message_id: "987654321",
      ...>   content: "Updated message content"
      ...> }, %{name: "Test Agent"})
      {:error, "Missing or invalid channel_id"}
  """

  use Lux.Prism,
    name: "Edit Discord Message",
    description: "Edits a message in a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel containing the message",
          pattern: "^[0-9]{17,20}$"
        },
        message_id: %{
          type: :string,
          description: "The ID of the message to edit",
          pattern: "^[0-9]{17,20}$"
        },
        content: %{
          type: :string,
          description: "The new content for the message",
          minLength: 1,
          maxLength: 2000
        }
      },
      required: ["channel_id", "message_id", "content"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        edited: %{
          type: :boolean,
          description: "Whether the message was successfully edited"
        }
      },
      required: ["edited"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to edit a message in a Discord channel.

  Returns {:ok, %{edited: true}} on success.
  Returns {:error, reason} on failure.
  """
  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, message_id} <- validate_param(params, :message_id),
         {:ok, content} <- validate_param(params, :content) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} editing message #{message_id} in channel #{channel_id}")

      case Client.request(:patch, "/channels/#{channel_id}/messages/#{message_id}", %{json: %{content: content}}) do
        {:ok, _} ->
          Logger.info("Successfully edited message #{message_id} in channel #{channel_id}")
          {:ok, %{edited: true}}
        error ->
          Logger.error("Failed to edit message #{message_id} in channel #{channel_id}: #{inspect(error)}")
          error
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
