defmodule Lux.Prisms.Discord.Webhook.DeleteWebhook do
  @moduledoc """
  Delete a webhook from a Discord channel.

  This prism removes an existing webhook permanently.

  Requires the \"Manage Webhooks\" permission.

  ## Examples

      iex> DeleteWebhook.handler(%{webhook_id: "123456789"}, %{name: "Agent"})
      {:ok, %{deleted: true, webhook_id: "123456789"}}
  """

  use Lux.Prism,
    name: "Delete Discord Webhook",
    description: "Deletes an existing webhook from a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        webhook_id: %{
          type: :string,
          description: "The ID of the webhook to delete",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["webhook_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        deleted: %{
          type: :boolean,
          description: "Whether the webhook was successfully deleted"
        },
        webhook_id: %{
          type: :string,
          description: "The ID of the deleted webhook"
        }
      },
      required: ["deleted", "webhook_id"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Deletes the specified webhook.

  Returns {:ok, %{deleted: true, webhook_id: id}} on success.
  """
  @spec handler(map(), map()) :: {:ok, map()} | {:error, any()}
  def handler(params, agent) do
    with {:ok, webhook_id} <- validate_webhook_id(params) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} deleting webhook #{webhook_id}")

      case Client.request(:delete, "/webhooks/#{webhook_id}") do
        {:ok, _} ->
          Logger.info("Successfully deleted webhook #{webhook_id}")
          {:ok, %{deleted: true, webhook_id: webhook_id}}

        {:error, {status, message}} ->
          Logger.error("Failed to delete webhook #{webhook_id}: #{inspect({status, message})}")
          {:error, {status, message}}

        {:error, error} ->
          Logger.error("Failed to delete webhook #{webhook_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_webhook_id(params) do
    case Map.fetch(params, :webhook_id) do
      {:ok, val} when is_binary(val) and byte_size(val) > 0 -> {:ok, val}
      _ -> {:error, "Missing or invalid webhook_id"}
    end
  end
end
