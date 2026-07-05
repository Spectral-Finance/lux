defmodule Lux.Prisms.Discord.Webhooks.ExecuteWebhook do
  use Lux.Prism,
    name: "Execute Webhook",
    description: "Sends a custom message via a webhook",
    input_schema: %{
      type: :object,
      properties: %{
        webhook_id: %{type: :string, description: "Webhook ID"},
        webhook_token: %{type: :string, description: "Webhook Token"},
        content: %{type: :string, description: "Message content"},
        username: %{type: :string, description: "Override the default username of the webhook"},
        avatar_url: %{type: :string, description: "Override the default avatar of the webhook"}
      },
      required: ["webhook_id", "webhook_token", "content"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        executed: %{type: :boolean}
      },
      required: ["executed"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, _agent) do
    id = params.webhook_id
    token = params.webhook_token
    
    payload = %{content: params.content}
    payload = if Map.has_key?(params, :username), do: Map.put(payload, :username, params.username), else: payload
    payload = if Map.has_key?(params, :avatar_url), do: Map.put(payload, :avatar_url, params.avatar_url), else: payload

    case Client.request(:post, "/webhooks/#{id}/#{token}", %{json: payload}) do
      {:ok, _} ->
        Logger.info("Executed webhook #{id}")
        {:ok, %{executed: true}}
      {:error, {status, %{"message" => message}}} ->
        {:error, {status, message}}
      {:error, error} ->
        {:error, error}
    end
  end
end
