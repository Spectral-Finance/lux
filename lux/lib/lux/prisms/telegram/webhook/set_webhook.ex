defmodule Lux.Prisms.Telegram.Webhook.SetWebhook do
  @moduledoc """
  A prism for setting a webhook for the bot via the Telegram Bot API.

  This prism provides an interface to call the setWebhook endpoint, which
  specifies a URL and receives incoming updates via an outgoing webhook.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /setWebhook
  - Requires url parameter
  - Optional certificate, ip_address, max_connections, allowed_updates,
    drop_pending_updates, secret_token parameters
  - Returns true on success

  ## Examples

      iex> SetWebhook.handler(%{url: "https://example.com/webhook"}, %{name: "Agent"})
      {:ok, %{success: true}}
  """

  use Lux.Prism,
    name: "Set Telegram Webhook",
    description: "Sets a webhook URL for receiving updates via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        url: %{
          type: :string,
          description: "HTTPS URL to send updates to. Use an empty string to remove webhook"
        },
        certificate: %{
          type: :string,
          description: "Upload your public key certificate so that the root certificate in use can be checked"
        },
        ip_address: %{
          type: :string,
          description: "The fixed IP address which will be used to send webhook requests"
        },
        max_connections: %{
          type: :integer,
          description: "The maximum allowed number of simultaneous HTTPS connections to the webhook (1-100, default 40)"
        },
        allowed_updates: %{
          type: :array,
          description: "A list of the update types you want your bot to receive",
          items: %{type: :string}
        },
        drop_pending_updates: %{
          type: :boolean,
          description: "Pass True to drop all pending updates"
        },
        secret_token: %{
          type: :string,
          description: "A secret token to be sent in the header X-Telegram-Bot-Api-Secret-Token (1-256 characters)"
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
        }
      },
      required: ["success"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to set a webhook.
  """
  def handler(params, agent) do
    with {:ok, url} <- validate_param(params, :url) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} setting webhook to #{url}")

      request_body = Map.take(params, [:url, :certificate, :ip_address, :max_connections,
                                        :allowed_updates, :drop_pending_updates, :secret_token])
      request_opts = %{json: request_body}
      request_opts = maybe_add_plug(request_opts, params[:plug])

      case Client.request(:post, "/setWebhook", request_opts) do
        {:ok, %{"result" => true}} ->
          Logger.info("Successfully set webhook")
          {:ok, %{success: true}}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to set webhook: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to set webhook: #{inspect(error)}"}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp maybe_add_plug(opts, nil), do: opts
  defp maybe_add_plug(opts, plug), do: Map.put(opts, :plug, plug)
end
