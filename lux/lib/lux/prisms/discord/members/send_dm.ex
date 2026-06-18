defmodule Lux.Prisms.Discord.Members.SendDM do
  @moduledoc """
  A prism for sending direct messages to Discord users.

  Uses Discord's DM channel creation API to establish a DM channel
  with the user, then sends the message through that channel.

  ## Examples
      iex> SendDM.handler(%{
      ...>   user_id: "987654321",
      ...>   content: "Hello from the bot!"
      ...> }, %{name: "Agent"})
      {:ok, %{
        sent: true,
        message_id: "111111111111111111",
        user_id: "987654321",
        content: "Hello from the bot!"
      }}
  """

  use Lux.Prism,
    name: "Send Discord DM",
    description: "Sends a direct message to a Discord user",
    input_schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :string,
          description: "The ID of the user to send a DM to",
          pattern: "^[0-9]{17,20}$"
        },
        content: %{
          type: :string,
          description: "The message content",
          minLength: 1,
          maxLength: 2000
        }
      },
      required: ["user_id", "content"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{
          type: :boolean,
          description: "Whether the DM was successfully sent"
        },
        message_id: %{
          type: :string,
          description: "The ID of the sent message"
        },
        user_id: %{
          type: :string,
          description: "The ID of the user the DM was sent to"
        },
        content: %{
          type: :string,
          description: "The content of the sent message"
        }
      },
      required: ["sent"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, user_id} <- validate_param(params, :user_id),
         {:ok, content} <- validate_param(params, :content) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} sending DM to user #{user_id}")

      with {:ok, %{"id" => channel_id}} <- create_dm_channel(user_id) do
        case Client.request(:post, "/channels/#{channel_id}/messages", %{json: %{content: content}}) do
          {:ok, %{"id" => message_id}} ->
            Logger.info("Successfully sent DM #{message_id} to user #{user_id}")
            {:ok, %{sent: true, message_id: message_id, user_id: user_id, content: content}}

          {:error, {status, %{"message" => message}}} ->
            error = {status, message}
            Logger.error("Failed to send DM to user #{user_id}: #{inspect(error)}")
            {:error, error}

          {:error, error} ->
            Logger.error("Failed to send DM to user #{user_id}: #{inspect(error)}")
            {:error, error}
        end
      end
    end
  end

  defp create_dm_channel(user_id) do
    case Client.request(:post, "/users/@me/channels", %{json: %{recipient_id: user_id}}) do
      {:ok, %{"id" => channel_id}} ->
        {:ok, %{"id" => channel_id}}

      {:error, {status, %{"message" => message}}} ->
        {:error, {status, message}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
