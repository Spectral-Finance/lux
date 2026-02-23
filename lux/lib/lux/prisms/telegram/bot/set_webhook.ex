defmodule Lux.Prisms.Telegram.Bot.SetWebhook do
  @moduledoc """
  A prism for configuring a webhook for the Telegram bot.

  Sets a webhook URL that Telegram will use to send updates to your bot
  instead of polling. Only one method can be active at a time — setting
  a webhook disables getUpdates.

  ## Examples

      iex> SetWebhook.handler(%{
      ...>   url: "https://example.com/webhook"
      ...> }, %{name: "Agent"})
      {:ok, %{success: true, description: "Webhook was set"}}

      iex> SetWebhook.handler(%{
      ...>   url: "https://example.com/webhook",
      ...>   max_connections: 40,
      ...>   allowed_updates: ["message", "callback_query"]
      ...> }, %{name: "Agent"})
      {:ok, %{success: true, description: "Webhook was set"}}
  """

  use Lux.Prism,
    name: "Set Telegram Webhook",
    description: "Configures a webhook URL for the Telegram bot to receive updates",
    input_schema: %{
      type: :object,
      properties: %{
        url: %{
          type: :string,
          description: "HTTPS URL to send updates to. Use empty string to remove webhook."
        },
        certificate: %{
          type: :string,
          description: "Upload your public key certificate so Telegram can verify the webhook."
        },
        ip_address: %{
          type: :string,
          description: "Fixed IP address to send requests to instead of resolving hostname."
        },
        max_connections: %{
          type: :integer,
          description: "Maximum allowed number of simultaneous HTTPS connections to the webhook (1-100). Defaults to 40."
        },
        allowed_updates: %{
          type: :array,
          items: %{type: :string},
          description: "List of update types to receive (e.g. [\"message\", \"callback_query\"]). Leave empty to receive all updates."
        },
        drop_pending_updates: %{
          type: :boolean,
          description: "Pass true to drop all pending updates when setting the webhook."
        },
        secret_token: %{
          type: :string,
          description: "A secret token (1-256 chars) to be sent in a header to verify requests are from Telegram."
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
        description: %{
          type: :string,
          description: "Human-readable description of the result"
        }
      },
      required: ["success"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, url} <- validate_url(params) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} setting Telegram webhook to #{url}")

      body =
        params
        |> Map.take([:url, :ip_address, :max_connections, :allowed_updates,
                     :drop_pending_updates, :secret_token])
        |> Map.put(:url, url)

      request_opts = %{json: body}
      request_opts = if plug = params[:plug], do: Map.put(request_opts, :plug, plug), else: request_opts

      case Client.request(:post, "/setWebhook", request_opts) do
        {:ok, %{"ok" => true, "result" => true, "description" => desc}} ->
          Logger.info("Webhook set successfully: #{desc}")
          {:ok, %{success: true, description: desc}}

        {:ok, %{"ok" => true, "result" => true}} ->
          {:ok, %{success: true, description: "Webhook was set"}}

        {:ok, %{"ok" => false, "description" => description}} ->
          {:error, "Failed to set webhook: #{description}"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to set webhook: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to set webhook: #{inspect(error)}"}
      end
    end
  end

  defp validate_url(params) do
    case params[:url] || params["url"] do
      nil -> {:error, "url is required"}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, "url must be a string"}
    end
  end
end
