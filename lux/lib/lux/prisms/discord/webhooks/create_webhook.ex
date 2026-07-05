defmodule Lux.Prisms.Discord.Webhooks.CreateWebhook do
  use Lux.Prism,
    name: "Create Webhook",
    description: "Creates a webhook in a channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "Channel ID"},
        name: %{type: :string, description: "Name of the webhook"},
        avatar: %{type: :string, description: "Image for the default webhook avatar in base64 URI format"}
      },
      required: ["channel_id", "name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        webhook_id: %{type: :string},
        token: %{type: :string},
        name: %{type: :string}
      },
      required: ["webhook_id", "token"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, _agent) do
    channel_id = params.channel_id
    payload = %{name: params.name}
    payload = if Map.has_key?(params, :avatar), do: Map.put(payload, :avatar, params.avatar), else: payload

    case Client.request(:post, "/channels/#{channel_id}/webhooks", %{json: payload}) do
      {:ok, %{"id" => id, "token" => token, "name" => name}} ->
        Logger.info("Created webhook #{id} in channel #{channel_id}")
        {:ok, %{webhook_id: id, token: token, name: name}}
      {:error, {status, %{"message" => message}}} ->
        {:error, {status, message}}
      {:error, error} ->
        {:error, error}
    end
  end
end
