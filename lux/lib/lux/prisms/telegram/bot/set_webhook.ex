defmodule Lux.Prisms.Telegram.Bot.SetWebhook do
  @moduledoc """
  A prism for registering a webhook URL to receive updates via the Telegram Bot API.

  Use this prism to have Telegram push updates to an HTTPS endpoint instead of using
  long polling (`GetUpdates`). You can optionally self-signed certificate parameters
  and choose which update types to receive.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /setWebhook
  - Supports optional parameters (url, certificate, ip_address, max_connections, allowed_updates, drop_pending_updates, secret_token)
  - Returns a simple success response
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      SetWebhook.handler(%{url: "https://example.com/telegram/webhook"}, %{name: "Agent"})
      #=> {:ok, %{webhook_set: true, url: "https://example.com/telegram/webhook"}}

      # Only receive message and callback_query updates, dropping pending ones
      SetWebhook.handler(%{
        url: "https://example.com/telegram/webhook",
        allowed_updates: ["message", "callback_query"],
        drop_pending_updates: true
      }, %{name: "Agent"})
      #=> {:ok, %{webhook_set: true, url: "https://example.com/telegram/webhook"}}
  """

  use Lux.Prism,
    name: "Set Telegram Webhook",
    description: "Registers a webhook URL to receive updates via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        url: %{
          type: :string,
          description: "HTTPS URL to send updates to. Use an empty string to remove webhook integration."
        },
        certificate: %{
          type: :string,
          description: "Upload your public key certificate so that the root certificate in use can be checked."
        },
        ip_address: %{
          type: :string,
          description: "The fixed IP address which will be used to send webhook requests instead of the IP address resolved through DNS."
        },
        max_connections: %{
          type: :integer,
          description: "Maximum allowed number of simultaneous HTTPS connections to the webhook for update delivery, 1-100. Defaults to 40."
        },
        allowed_updates: %{
          type: :array,
          description: "A JSON-serialized list of the update types you want your bot to receive (e.g. [\"message\", \"callback_query\"])."
        },
        drop_pending_updates: %{
          type: :boolean,
          description: "Pass True to drop all pending updates before applying the webhook."
        },
        secret_token: %{
          type: :string,
          description: "A secret token to be sent in a header \"X-Telegram-Bot-Api-Secret-Token\" with every webhook request, 1-256 characters."
        }
      },
      required: ["url"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        webhook_set: %{
          type: :boolean,
          description: "Whether the webhook was successfully set"
        },
        url: %{
          type: :string,
          description: "The webhook URL that was registered"
        }
      },
      required: ["webhook_set", "url"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to register a webhook URL.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, url} <- validate_url(params) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} setting webhook to #{url}")

      request_body =
        Map.take(
          params,
          [
            :url,
            :certificate,
            :ip_address,
            :max_connections,
            :allowed_updates,
            :drop_pending_updates,
            :secret_token
          ]
        )

      case Client.request(:post, "/setWebhook", %{json: request_body}) do
        {:ok, %{"result" => true}} ->
          Logger.info("Successfully set webhook to #{url}")
          {:ok, %{webhook_set: true, url: url}}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to set webhook: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to set webhook: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to set webhook: #{inspect(error)}"}
      end
    end
  end

  defp validate_url(params) do
    case Map.fetch(params, :url) do
      {:ok, url} when is_binary(url) and url != "" -> {:ok, url}
      _ -> {:error, "Missing or invalid url"}
    end
  end
end