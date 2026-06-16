defmodule Lux.Prisms.Telegram.Webhook.DeleteWebhook do
  @moduledoc """
  A prism for deleting webhook settings from the Telegram Bot API.

  ## Examples

      iex> DeleteWebhook.handler(%{}, %{name: "Agent"})
      {:ok, %{success: true}}
  """

  use Lux.Prism,
    name: "Delete Telegram Webhook",
    description: "Deletes webhook settings using deleteWebhook",
    input_schema: %{
      type: :object,
      properties: %{
        drop_pending_updates: %{
          type: :boolean,
          description: "Pass True to drop all pending updates"
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether the webhook was successfully deleted"
        }
      },
      required: ["success"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles deleting the Telegram webhook.
  """
  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} deleting webhook")

    api_params = Map.take(params, [:drop_pending_updates])

    case Client.request(:post, "/deleteWebhook", %{json: api_params}) do
      {:ok, _response} ->
        {:ok, %{success: true}}

      {:error, {status, %{"description" => description}}} ->
        {:error, "Failed to delete webhook: #{description} (HTTP #{status})"}

      {:error, {status, description}} when is_binary(description) ->
        {:error, "Failed to delete webhook: #{description} (HTTP #{status})"}

      {:error, error} ->
        {:error, "Failed to delete webhook: #{inspect(error)}"}
    end
  end
end
