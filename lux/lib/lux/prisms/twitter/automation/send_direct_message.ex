defmodule Lux.Prisms.Twitter.Automation.SendDirectMessage do
  @moduledoc """
  A prism for sending direct messages (DMs) to Twitter users.

  Enables agents to automate personalized outreach via direct messages,
  supporting engagement automation and relationship management workflows.

  ## Examples

      iex> SendDirectMessage.handler(%{
      ...>   participant_id: "987654321",
      ...>   text: "Hi! Thanks for following. Check out our latest content!"
      ...> }, %{name: "OutreachBot"})
      {:ok, %{sent: true, dm_conversation_id: "...", message_id: "..."}}
  """

  use Lux.Prism,
    name: "Send Twitter Direct Message",
    description: "Send an automated direct message to a Twitter user",
    input_schema: %{
      type: :object,
      properties: %{
        participant_id: %{
          type: :string,
          description: "Twitter user ID of the DM recipient"
        },
        text: %{
          type: :string,
          description: "Text content of the direct message"
        },
        media_id: %{
          type: :string,
          description: "Optional media attachment ID"
        },
        dm_conversation_id: %{
          type: :string,
          description: "Existing DM conversation ID to reply into"
        }
      },
      required: ["participant_id", "text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{type: :boolean, description: "Whether the DM was sent successfully"},
        dm_conversation_id: %{type: :string, description: "ID of the DM conversation"},
        message_id: %{type: :string, description: "ID of the sent message"},
        participant_id: %{type: :string, description: "Recipient user ID"}
      },
      required: ["sent", "participant_id"]
    }

  alias Lux.Integrations.Twitter.Client
  require Logger

  @doc """
  Sends a direct message to the specified Twitter user.
  """
  def handler(%{participant_id: participant_id, text: text} = params, agent) do
    with :ok <- validate_dm_text(text) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} sending DM to user #{participant_id}")

      dm_body =
        %{
          "participant_id" => participant_id,
          "message_create" => %{"text" => text}
        }
        |> maybe_add_media(params)
        |> maybe_add_conversation(params)

      case Client.request(:post, "/dm_conversations/with/#{participant_id}/messages", %{json: dm_body}) do
        {:ok, %{"data" => data}} ->
          Logger.info("DM sent successfully to user #{participant_id}")
          {:ok, %{
            sent: true,
            dm_conversation_id: data["dm_conversation_id"],
            message_id: data["dm_event_id"],
            participant_id: participant_id
          }}

        {:error, :rate_limited} ->
          {:error, "Rate limit exceeded for DM operations"}

        {:error, {status, message}} ->
          {:error, "Failed to send DM: #{message} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to send DM: #{inspect(error)}"}
      end
    end
  end

  def handler(params, _agent) do
    missing = Enum.reject([:participant_id, :text], &Map.has_key?(params, &1))
    {:error, "Missing required parameters: #{Enum.join(missing, ", ")}"}
  end

  defp validate_dm_text(text) when byte_size(text) == 0, do: {:error, "DM text cannot be empty"}
  defp validate_dm_text(text) when byte_size(text) > 10_000, do: {:error, "DM text too long (max 10,000 characters)"}
  defp validate_dm_text(_text), do: :ok

  defp maybe_add_media(body, %{media_id: id}) when is_binary(id) and id != "",
    do: put_in(body, ["message_create", "attachments"], [%{"media_id" => id}])
  defp maybe_add_media(body, _), do: body

  defp maybe_add_conversation(body, %{dm_conversation_id: id}) when is_binary(id) and id != "",
    do: Map.put(body, "dm_conversation_id", id)
  defp maybe_add_conversation(body, _), do: body
end
