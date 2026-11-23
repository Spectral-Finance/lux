defmodule Lux.Prisms.Telegram.Bot.GetWebhookInfo do
  @moduledoc """
  A prism for retrieving the current webhook status via the Telegram Bot API.

  Use this prism to inspect whether a webhook is configured, its URL, pending update
  count, and (if delivery is failing) the last error details. This is the primary tool
  for debugging webhook integration and updates handling.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /getWebhookInfo
  - Requires no parameters beyond the configured bot token
  - Returns the normalized webhook info map
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      GetWebhookInfo.handler(%{}, %{name: "Agent"})
      #=> {:ok, %{url: "https://example.com/telegram/webhook", has_custom_certificate: false,
      #=>        pending_update_count: 0}}

      # No webhook configured
      GetWebhookInfo.handler(%{}, %{name: "Agent"})
      #=> {:ok, %{url: "", has_custom_certificate: false, pending_update_count: 0}}
  """

  use Lux.Prism,
    name: "Get Telegram Webhook Info",
    description: "Returns the current webhook status (URL, pending updates, last error) via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{},
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        url: %{
          type: :string,
          description: "Webhook URL, or empty string if no webhook is set"
        },
        has_custom_certificate: %{
          type: :boolean,
          description: "True if a custom certificate was provided for webhook certificate checks"
        },
        pending_update_count: %{
          type: :integer,
          description: "Number of updates awaiting delivery"
        },
        ip_address: %{
          type: :string,
          description: "Currently used webhook IP address, if set"
        },
        last_error_date: %{
          type: :integer,
          description: "Unix time for the most recent error that happened when trying to deliver an update via webhook"
        },
        last_error_message: %{
          type: :string,
          description: "Human-readable description of the most recent error for webhook delivery"
        },
        max_connections: %{
          type: :integer,
          description: "Maximum allowed number of simultaneous HTTPS connections to the webhook"
        },
        allowed_updates: %{
          type: :array,
          description: "A list of update types the bot is subscribed to. Empty if not set."
        }
      },
      required: ["url", "has_custom_certificate", "pending_update_count"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to fetch the current webhook status.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns the normalized webhook info map
  - Logs the operation for monitoring purposes
  """
  def handler(_params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} fetching webhook info (getWebhookInfo)")

    case Client.request(:post, "/getWebhookInfo", %{json: %{}}) do
      {:ok, %{"result" => result}} when is_map(result) ->
        Logger.info("Fetched webhook info for url: #{inspect(result["url"])}")

        {:ok,
         %{
           url: result["url"],
           has_custom_certificate: result["has_custom_certificate"],
           pending_update_count: result["pending_update_count"],
           ip_address: result["ip_address"],
           last_error_date: result["last_error_date"],
           last_error_message: result["last_error_message"],
           max_connections: result["max_connections"],
           allowed_updates: result["allowed_updates"]
         }}

      {:error, {status, %{"description" => description}}} ->
        {:error, "Failed to get webhook info: #{description} (HTTP #{status})"}

      {:error, {status, description}} when is_binary(description) ->
        {:error, "Failed to get webhook info: #{description} (HTTP #{status})"}

      {:error, error} ->
        {:error, "Failed to get webhook info: #{inspect(error)}"}
    end
  end
end