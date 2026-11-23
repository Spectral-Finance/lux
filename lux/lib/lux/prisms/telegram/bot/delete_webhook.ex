defmodule Lux.Prisms.Telegram.Bot.DeleteWebhook do
  @moduledoc """
  A prism for removing a webhook integration via the Telegram Bot API.

  Use this prism to delete a previously configured webhook so that the bot falls back
  to receiving updates via `GetUpdates` (long polling). Optionally drop pending updates.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /deleteWebhook
  - Supports optional parameter (drop_pending_updates)
  - Returns a simple success response
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      DeleteWebhook.handler(%{}, %{name: "Agent"})
      #=> {:ok, %{webhook_deleted: true}}

      # Delete the webhook and drop all pending updates
      DeleteWebhook.handler(%{drop_pending_updates: true}, %{name: "Agent"})
      #=> {:ok, %{webhook_deleted: true}}
  """

  use Lux.Prism,
    name: "Delete Telegram Webhook",
    description: "Removes the webhook integration so the bot uses long polling via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        drop_pending_updates: %{
          type: :boolean,
          description: "Pass True to drop all pending updates before deleting the webhook."
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        webhook_deleted: %{
          type: :boolean,
          description: "Whether the webhook was successfully deleted"
        }
      },
      required: ["webhook_deleted"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to delete a webhook.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} deleting webhook (deleteWebhook)")

    request_body = Map.take(params, [:drop_pending_updates])

    case Client.request(:post, "/deleteWebhook", %{json: request_body}) do
      {:ok, %{"result" => true}} ->
        Logger.info("Successfully deleted webhook")
        {:ok, %{webhook_deleted: true}}

      {:error, {status, %{"description" => description}}} ->
        {:error, "Failed to delete webhook: #{description} (HTTP #{status})"}

      {:error, {status, description}} when is_binary(description) ->
        {:error, "Failed to delete webhook: #{description} (HTTP #{status})"}

      {:error, error} ->
        {:error, "Failed to delete webhook: #{inspect(error)}"}
    end
  end
end