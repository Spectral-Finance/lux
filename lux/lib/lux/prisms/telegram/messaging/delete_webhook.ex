defmodule Lux.Prisms.Telegram.Messaging.DeleteWebhook do
  @moduledoc """
  A prism for deleting the Telegram webhook.
  """

  use Lux.Prism,
    name: "Delete Telegram Webhook",
    description: "Deletes the current Telegram webhook",
    input_schema: %{
      type: :object,
      properties: %{
        drop_pending_updates: %{type: :boolean, description: "Drop all pending updates"}
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        deleted: %{type: :boolean, description: "Whether the webhook was deleted"}
      },
      required: ["deleted"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} deleting webhook")

    json = case Map.fetch(params, :drop_pending_updates) do
      {:ok, value} -> %{drop_pending_updates: value}
      :error -> %{}
    end

    case Client.request(:post, "/deleteWebhook", %{json: json}) do
      {:ok, _result} ->
        Logger.info("Successfully deleted webhook")
        {:ok, %{deleted: true}}

      {:error, {status, description}} ->
        Logger.error("Failed to delete webhook: {#{status}, #{description}}")
        {:error, {status, description}}

      {:error, error} ->
        Logger.error("Failed to delete webhook: #{inspect(error)}")
        {:error, error}
    end
  end
end
