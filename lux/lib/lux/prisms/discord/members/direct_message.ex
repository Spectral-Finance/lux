defmodule Lux.Prisms.Discord.Members.DirectMessage do
  @moduledoc """
  A prism for sending a direct message to a Discord user.

  ## Examples

      iex> DirectMessage.handler(%{
      ...>   user_id: "222222222222222222",
      ...>   content: "Hello from the agent!"
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, channel_id: "333333333333333333", message_id: "444444444444444444"}}
  """

  use Lux.Prism,
    name: "Send Discord Direct Message",
    description: "Sends a direct message to a Discord user",
    input_schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :string,
          description: "The ID of the user to message",
          pattern: "^[0-9]{17,20}$"
        },
        content: %{
          type: :string,
          description: "The content of the message",
          minLength: 1,
          maxLength: 2000
        },
        embeds: %{
          type: :array,
          description: "Optional rich embeds to include in the message",
          items: %{type: :object}
        }
      },
      required: ["user_id", "content"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{type: :boolean, description: "Whether the message was successfully sent"},
        channel_id: %{type: :string, description: "The ID of the DM channel"},
        message_id: %{type: :string, description: "The ID of the sent message"}
      },
      required: ["sent"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, user_id} <- validate_param(params, :user_id),
         {:ok, content} <- validate_param(params, :content),
         {:ok, embeds} <- validate_optional_param(params, :embeds) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} sending DM to user #{user_id}")

      with {:ok, %{"id" => channel_id}} <- create_dm_channel(user_id),
           {:ok, message} <- send_message(channel_id, content, embeds) do
        Logger.info("Successfully sent DM to user #{user_id}")
        {:ok, %{sent: true, channel_id: channel_id, message_id: message["id"]}}
      else
        error ->
          Logger.error("Failed to send DM: #{inspect(error)}")
          error
      end
    end
  end

  defp create_dm_channel(user_id) do
    Client.request(:post, "/users/@me/channels", %{json: %{recipient_id: user_id}})
  end

  defp send_message(channel_id, content, nil) do
    Client.request(:post, "/channels/#{channel_id}/messages", %{json: %{content: content}})
  end

  defp send_message(channel_id, content, embeds) do
    Client.request(:post, "/channels/#{channel_id}/messages", %{json: %{content: content, embeds: embeds}})
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_optional_param(params, key, default \\ nil) do
    case Map.get(params, key, default) do
      nil -> {:ok, nil}
      value -> {:ok, value}
    end
  end
end
