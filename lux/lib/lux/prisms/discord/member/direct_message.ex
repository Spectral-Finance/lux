defmodule Lux.Prisms.Discord.Member.DirectMessage do
  use Lux.Prism,
    name: "Send Discord Direct Message",
    description: "Sends a direct message to a Discord user by creating a DM channel",
    input_schema: %{
      type: :object,
      properties: %{
        recipient_id: %{type: :string, description: "User ID to message", pattern: "^[0-9]{17,20}$"},
        content: %{type: :string, description: "Message content", minLength: 1, maxLength: 2000}
      },
      required: ["recipient_id", "content"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{type: :boolean},
        message_id: %{type: :string},
        channel_id: %{type: :string}
      },
      required: ["sent"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} sending DM to user #{params[:recipient_id]}")

    with {:ok, %{"id" => channel_id}} <- Client.request(:post, "/users/@me/channels", %{json: %{recipient_id: params[:recipient_id]}}),
         {:ok, response} <- Client.request(:post, "/channels/#{channel_id}/messages", %{json: %{content: params[:content]}}) do
      {:ok, %{sent: true, message_id: response["id"], channel_id: channel_id}}
    else
      {:error, error} -> {:error, error}
    end
  end
end
