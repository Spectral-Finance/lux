defmodule Lux.Prisms.Telegram.Webhook.SetWebhook do
  @moduledoc """
  A prism for configuring webhooks for incoming updates.

  ## Examples

      # Set a simple webhook URL
      iex> SetWebhook.handler(%{
      ...>   url: "https://example.com/webhook"
      ...> }, %{name: "Agent"})
      {:ok, %{success: true, url: "https://example.com/webhook"}}

      # Set a webhook URL with a secret token for security
      iex> SetWebhook.handler(%{
      ...>   url: "https://example.com/webhook",
      ...>   secret_token: "secure-secret-12345"
      ...> }, %{name: "Agent"})
      {:ok, %{success: true, url: "https://example.com/webhook"}}
  """

  use Lux.Prism,
    name: "Set Telegram Webhook",
    description: "Configures webhook settings using setWebhook",
    input_schema: %{
      type: :object,
      properties: %{
        url: %{
          type: :string,
          description: "HTTPS URL to send updates to. Use an empty string to remove webhook integration"
        },
        certificate: %{
          type: :string,
          description: "Path to your public key certificate file so that the root certificate in use can be checked"
        },
        ip_address: %{
          type: :string,
          description: "The fixed IP address which will be used to send webhook requests instead of DNS resolved IP"
        },
        max_connections: %{
          type: :integer,
          description: "The maximum allowed number of simultaneous HTTPS connections for webhook delivery (1-100)",
          minimum: 1,
          maximum: 100
        },
        allowed_updates: %{
          type: :array,
          description: "A JSON-serialized list of the update types you want your bot to receive",
          items: %{
            type: :string
          }
        },
        drop_pending_updates: %{
          type: :boolean,
          description: "Pass True to drop all pending updates"
        },
        secret_token: %{
          type: :string,
          description: "A secret token to be sent in a header \"X-Telegram-Bot-Api-Secret-Token\" in every webhook request (1-256 characters)"
        }
      },
      required: ["url"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether the webhook was successfully set"
        },
        url: %{
          type: :string,
          description: "The webhook URL that was set"
        }
      },
      required: ["success", "url"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles setting the Telegram webhook.
  """
  def handler(params, agent) do
    params = Lux.Integrations.Telegram.normalize_keys(params)

    case Map.fetch(params, :url) do
      {:ok, url} when is_binary(url) ->
        agent_name = agent[:name] || "Unknown Agent"
        Logger.info("Agent #{agent_name} setting webhook to #{url}")

        api_params = Map.take(params, [:url, :certificate, :ip_address, :max_connections, :allowed_updates, :drop_pending_updates, :secret_token])

        result =
          if Map.has_key?(api_params, :certificate) do
            Client.multipart_request(:post, "/setWebhook", api_params)
          else
            Client.request(:post, "/setWebhook", %{json: api_params})
          end

        case result do
          {:ok, _response} ->
            {:ok, %{success: true, url: url}}

          {:error, {status, description}} when is_binary(description) ->
            {:error, "Failed to set webhook: #{description} (HTTP #{status})"}

          {:error, error} ->
            {:error, "Failed to set webhook: #{inspect(error)}"}
        end

      _ ->
        {:error, "Missing or invalid url"}
    end
  end
end
