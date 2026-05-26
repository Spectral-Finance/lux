defmodule Lux.Prisms.Telegram.Management.SetWebhook do
  @moduledoc """
  A prism for specifying a URL and receiving incoming updates via an outgoing webhook.
  """

  alias Lux.Integrations.Telegram.Client

  use Lux.Prism,
    name: "Set Telegram Webhook",
    description: "Specifies a URL and receives incoming updates via an outgoing webhook",
    input_schema: %{
      type: :object,
      properties: %{
        url: %{type: :string, description: "HTTPS URL to send updates to"},
        certificate: %{type: :string, description: "Upload your public key certificate so that the root certificate in use can be checked"},
        ip_address: %{type: :string, description: "The fixed IP address which will be used to send webhook requests instead of the IP address resolved through DNS"},
        max_connections: %{type: :integer, description: "The maximum allowed number of simultaneous HTTPS connections to the webhook for update delivery", minimum: 1, maximum: 100, default: 40},
        allowed_updates: %{type: :array, items: %{type: :string}, description: "A JSON-serialized list of the update types you want your bot to receive"},
        drop_pending_updates: %{type: :boolean, description: "Pass True to drop all pending updates"},
        secret_token: %{type: :string, description: "A secret token to be sent in a header “X-Telegram-Bot-Api-Secret-Token” in every webhook request"}
      },
      required: ["url"]
    }

  def handler(params, _agent) do
    case Client.request(:post, "/setWebhook", %{json: params}) do
      {:ok, %{"ok" => true, "result" => true}} ->
        {:ok, %{success: true}}

      {:ok, response} ->
        {:error, response}

      {:error, error} ->
        {:error, error}
    end
  end
end
